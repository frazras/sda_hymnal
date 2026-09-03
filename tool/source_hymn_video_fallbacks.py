#!/usr/bin/env python3
"""Source conservative YouTube fallbacks for hymns missing channel matches.

This is a maintainer tool, not app runtime code. It uses yt-dlp's YouTube
search extractor and records only results whose title substantially contains
the requested hymn title. Reviewable results are written to the source-data
JSON consumed by build_hymn_videos.py.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import threading
import unicodedata
from concurrent.futures import ThreadPoolExecutor, as_completed
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "tool/data/hymn_metadata_sources/youtube_search_fallbacks.json"
VIDEOS = ROOT / "assets/hymn_videos.json"
STOP_WORDS = {
    "a", "an", "and", "as", "at", "by", "for", "from", "in", "is",
    "my", "of", "o", "on", "our", "the", "thy", "to", "we", "with",
}
REJECT_WORDS = {
    "sermon", "preaching", "homily", "podcast", "reaction", "tutorial",
    "lesson", "documentary", "interview", "behind the hymn", "story of",
}
TUNE_MATCH_ALLOWLIST = {
    # Manually reviewed: these videos name the exact tune attached to the
    # inherited Old Hymnal record, even where they demonstrate other words.
    "gentle-peace-from-heaven-descended",
    "have-i-need-of-aught-o-saviour",
    "in-our-hearts-celestial-voices",
    "lord-thy-children-guide",
    "my-blest-redeemer",
}


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value or "")
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.casefold().replace("&", " and ").replace("'", "")
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", value)).strip()


def title_score(wanted: str, result: dict[str, Any], new_numbers: list[int]) -> float:
    actual = normalize(result.get("title", ""))
    target = normalize(wanted)
    if not actual or any(term in actual for term in REJECT_WORDS):
        return -1.0

    target_tokens = set(target.split())
    content_tokens = target_tokens - STOP_WORDS or target_tokens
    actual_tokens = set(actual.split())
    coverage = len(content_tokens & actual_tokens) / max(1, len(content_tokens))
    phrase = target in actual
    similarity = SequenceMatcher(None, target, actual).ratio()
    number_match = any(
        re.search(rf"(?:^|\D)0*{number}(?:\D|$)", actual)
        for number in new_numbers
    )
    score = coverage * 0.58 + similarity * 0.27
    if phrase:
        score += 0.18
    if number_match:
        score += 0.12
    if "lyrics" in actual or "with words" in actual:
        score += 0.04
    if "hymn" in actual:
        score += 0.02
    # A result must contain nearly all meaningful title words. Short titles
    # need either the whole phrase or the exact New Hymnal number as context.
    if coverage < 0.72:
        return -1.0
    if len(content_tokens) <= 2 and not phrase and not number_match:
        return -1.0
    return score


def search(work: dict[str, Any]) -> tuple[str, dict[str, Any] | None, str | None]:
    title = work["title"]
    new_numbers = work["numbers"]["new"]
    old_numbers = work["numbers"]["old"]
    primary = (
        f'SDA Hymnal {new_numbers[0]} "{title}" lyrics'
        if new_numbers else f'"{title}" hymn lyrics'
    )
    queries = [primary]
    if old_numbers:
        queries.append(f'Old SDA Church Hymnal {old_numbers[0]} "{title}"')
    # Some rare inherited titles have spelling/transcription errors. A plain
    # exact-title search provides a second discovery route while the same
    # conservative result-title score remains mandatory.
    queries.append(f'"{title.replace("Cloosing", "Closing")}"')

    ranked: list[tuple[float, dict[str, Any], str]] = []
    errors: list[str] = []
    for query in queries:
        command = [
            "yt-dlp", "--flat-playlist", "--playlist-end", "5",
            "--dump-single-json", "--no-warnings", f"ytsearch5:{query}",
        ]
        try:
            completed = subprocess.run(
                command, capture_output=True, text=True, timeout=35, check=True,
            )
            payload = json.loads(completed.stdout)
        except (subprocess.SubprocessError, json.JSONDecodeError) as error:
            errors.append(str(error))
            continue
        ranked.extend(
            (title_score(title.replace("Cloosing", "Closing"), result, new_numbers), result, query)
            for result in payload.get("entries", [])
            if result and result.get("id") and result.get("title")
        )
        if ranked and max(item[0] for item in ranked) >= 0.90:
            break

    ranked.sort(key=lambda item: item[0], reverse=True)
    matched_by = "title"
    if not ranked or ranked[0][0] < 0.72:
        ranked = []
        tunes = work.get("tuneTitles", []) if work["id"] in TUNE_MATCH_ALLOWLIST else []
        for tune in tunes:
            query = f'"{tune}" hymn tune organ'
            command = [
                "yt-dlp", "--flat-playlist", "--playlist-end", "5",
                "--dump-single-json", "--no-warnings", f"ytsearch5:{query}",
            ]
            try:
                completed = subprocess.run(
                    command, capture_output=True, text=True, timeout=35, check=True,
                )
                payload = json.loads(completed.stdout)
            except (subprocess.SubprocessError, json.JSONDecodeError) as error:
                errors.append(str(error))
                continue
            for result in payload.get("entries", []):
                if not result or not result.get("id") or not result.get("title"):
                    continue
                actual = normalize(result["title"])
                target = normalize(tune)
                if target in actual and any(
                    word in actual for word in ("hymn", "tune", "organ", "psalm", "melody")
                ):
                    ranked.append((0.75 + 0.2 * SequenceMatcher(None, target, actual).ratio(), result, query))
        ranked.sort(key=lambda item: item[0], reverse=True)
        matched_by = "tune"
    if not ranked or ranked[0][0] < 0.72:
        return work["id"], None, "; ".join(errors) or None
    score, result, query = ranked[0]
    return work["id"], {
        "youtubeVideoId": result["id"],
        "title": result["title"],
        "channel": result.get("channel") or result.get("uploader") or "YouTube",
        "channelId": result.get("channel_id") or result.get("uploader_id") or "",
        "query": query,
        "matchScore": round(score, 4),
        "matchedBy": matched_by,
    }, None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    catalog = json.loads(VIDEOS.read_text(encoding="utf-8"))
    metadata = json.loads((ROOT / "assets/hymn_metadata.json").read_text(encoding="utf-8"))
    metadata_by_id = {work["id"]: work for work in metadata["hymns"]}
    existing = {} if args.refresh else json.loads(OUTPUT.read_text(encoding="utf-8"))
    existing = {
        work_id: value
        for work_id, value in existing.items()
        if value.get("matchedBy") != "tune" or work_id in TUNE_MATCH_ALLOWLIST
    }
    works = []
    for work in catalog["unmatchedWorks"]:
        if work["id"] in existing:
            continue
        enriched = dict(work)
        record = metadata_by_id[work["id"]]
        enriched["tuneTitles"] = sorted({
            edition["tuneTitle"]
            for editions in record.get("editions", {}).values()
            for edition in editions
            if edition.get("tuneTitle")
        })
        works.append(enriched)
    if args.limit is not None:
        works = works[: args.limit]

    lock = threading.Lock()
    complete = 0
    matched = 0
    errors: list[tuple[str, str]] = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(search, work): work for work in works}
        for future in as_completed(futures):
            work_id, result, error = future.result()
            with lock:
                complete += 1
                if result is not None:
                    existing[work_id] = result
                    matched += 1
                if error is not None:
                    errors.append((work_id, error))
                if complete % 25 == 0 or complete == len(works):
                    print(f"Searched {complete}/{len(works)}; matched {matched}", flush=True)

    OUTPUT.write_text(
        json.dumps(dict(sorted(existing.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUTPUT}: {len(existing)} total fallbacks; {len(errors)} errors")
    for work_id, error in errors[:10]:
        print(f"  {work_id}: {error}")


if __name__ == "__main__":
    main()
