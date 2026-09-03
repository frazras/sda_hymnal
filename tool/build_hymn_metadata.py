#!/usr/bin/env python3
"""Build the app's sanitized hymn credits and story catalog.

The raw commissioned scrapes stay in tool/data so no source information is
lost.  This script creates a deterministic, app-safe JSON asset from them and
from public hymnal catalogs.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import re
import unicodedata
from collections import Counter, defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tool" / "data" / "hymn_metadata_sources"

TITLE_ALIASES = {
    "a mighty fortress is our god": "a mighty fortress",
    "all hail power of jesus": "all hail the power of jesus name",
    "all hail the power of jesus": "all hail the power of jesus name",
    "alas and did my savior bleed": "alas and did my saviour bleed",
    "blessed assurance": "blessed assurance jesus is mine",
    "child of the king": "a child of the king",
    "christ arose": "low in the grave he lay",
    "come thou fount of every blessing": "come thou fount of every blessing",
    "doxology": "praise god from whom all blessings",
    "go tell it on the mountain": "go tell it on the mountain",
    "god will take care of you": "god will take care of you",
    "he leadeth me": "he leadeth me",
    "his eye is on the sparrow": "his eye is on the sparrow",
    "it is well with my soul": "when peace like a river",
    "jesus loves me": "jesus loves me",
    "o god our help in ages past": "o god our help",
    "rock of ages": "rock of ages",
    "silent night": "silent night holy night",
    "silent night holy night": "silent night holy night",
    "standing on the promises": "standing on the promises",
    "sunshine in my soul": "theres sunshine in my soul today",
    "the ninety and nine": "there were ninety and nine",
    "there is a balm in gilead": "there is a balm in gilead",
    "there is a fountain filled with blood": "there is a fountain",
    "this is my fathers world": "this is my fathers world",
    "throw out the life line": "throw out the lifeline",
    "what a friend": "what a friend we have in jesus",
    "what a friend we have in jesus": "what a friend we have in jesus",
    "when they ring those golden bells": "when they ring the golden bells",
    "yes jesus loves me": "jesus loves me",
}


def compact_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalize_title(value: str) -> str:
    value = html.unescape(value or "")
    value = re.sub(r",?\s+the song and the story\s*$", "", value, flags=re.I)
    value = re.sub(r"\s*\(\d+\)\s*$", "", value)
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.casefold().replace("&", " and ").replace("'", "")
    return compact_space(re.sub(r"[^a-z0-9]+", " ", value))


def clean_title(value: str) -> str:
    value = html.unescape(value or "").replace("~", " ")
    value = re.sub(r",?\s+the song and the story\s*$", "", value, flags=re.I)
    value = re.sub(r"\s*\(\d+\)\s*$", "", value)
    return compact_space(value)


def slug(value: str) -> str:
    result = normalize_title(value).replace(" ", "-")
    return result or "untitled"


def clean_story(value: str) -> str:
    value = html.unescape(value or "")
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = value.split(re.search(r"\+{5,}", value).group(0), 1)[0] if re.search(r"\+{5,}", value) else value
    value = value.replace("~", " ").replace("\u00a0", " ")
    lines = [compact_space(line) for line in value.splitlines()]
    value = "\n".join(lines)
    return re.sub(r"\n{3,}", "\n\n", value).strip(" \n+")


def plain_lyric_lines(body: str) -> list[str]:
    body = re.sub(r"<br\s*/?>", "\n", body, flags=re.I)
    body = re.sub(r"<[^>]+>", "", body)
    lines = []
    for line in html.unescape(body).splitlines():
        normalized = normalize_title(re.sub(r"^(chorus|refrain)\s*:?\s*", "", line, flags=re.I))
        if len(normalized) >= 10 and not normalized.isdigit():
            lines.append(normalized)
    return lines


def strip_faith_lyrics(story: str, title: str, lyric_lines: list[str]) -> str:
    lines = story.splitlines()
    source_title = normalize_title(title)
    lyric_set = set(lyric_lines)
    start_at = max(4, len(lines) // 4)
    for index in range(start_at, len(lines)):
        current = normalize_title(lines[index])
        if not current:
            continue
        heading = current == source_title and index > len(lines) // 3
        lyric = current in lyric_set
        if not lyric and len(current) >= 18:
            lyric = any(SequenceMatcher(None, current, candidate).ratio() >= 0.94 for candidate in lyric_lines)
        if heading or lyric:
            while index > 0 and not lines[index - 1].strip():
                index -= 1
            return "\n".join(lines[:index]).strip()
    return story


def split_names(value: str) -> list[str]:
    if not value:
        return []
    parts = re.split(r"\s*(?:;|\band\b|\|)\s*", value)
    return [compact_space(part) for part in parts if compact_space(part)]


def unique(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        key = value.casefold()
        if value and key not in seen:
            result.append(value)
            seen.add(key)
    return result


def merge_people(values: list[str]) -> list[str]:
    """Deduplicate short and dated forms of the same person's name."""
    order: list[str] = []
    best: dict[str, str] = {}
    for value in values:
        base = normalize_title(re.sub(r"\s*\([^)]*\)\s*$", "", value))
        if not base:
            continue
        if base not in best:
            order.append(base)
            best[base] = value
        elif len(value) > len(best[base]):
            best[base] = value
    return [best[key] for key in order]


def csv_metadata(row: dict[str, str], source_id: str) -> dict[str, Any]:
    return {
        "authors": split_names(row.get("authors", "")),
        "composers": split_names(row.get("composers", "")),
        "firstLine": compact_space(row.get("firstLine", "")),
        "refrainFirstLine": compact_space(row.get("refrainFirstLine", "")),
        "meter": compact_space(row.get("meter", "")),
        "tuneTitle": compact_space(row.get("tuneTitle", "")),
        "languages": split_names(row.get("languages", "")),
        "textSources": split_names(row.get("textSources", "")),
        "tuneSources": split_names(row.get("tuneSources", "")),
        "sourceId": source_id,
    }


def without_empty(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: without_empty(item) for key, item in value.items() if item not in (None, "", [], {})}
    if isinstance(value, list):
        return [without_empty(item) for item in value]
    return value


def publish_hymn(record: dict[str, Any]) -> dict[str, Any]:
    """Keep formal empty fields while pruning optional nested metadata."""
    published = without_empty(record)
    published["numbers"] = {
        "old": record["numbers"]["old"],
        "new": record["numbers"]["new"],
    }
    published["authors"] = record["authors"]
    published["composers"] = record["composers"]
    published["authorStatus"] = (
        "documented" if record["authors"] else "not documented in available sources"
    )
    published["editions"] = {
        "old": [without_empty(item) for item in record["editions"]["old"]],
        "new": [without_empty(item) for item in record["editions"]["new"]],
    }
    published["stories"] = record["stories"]
    return published


def match_title(title: str, app_titles: dict[str, str]) -> str | None:
    normalized = normalize_title(title)
    candidate = TITLE_ALIASES.get(normalized, normalized)
    if candidate in app_titles:
        return candidate
    scores = sorted(
        ((SequenceMatcher(None, candidate, key).ratio(), key) for key in app_titles),
        reverse=True,
    )
    if scores and scores[0][0] >= 0.94 and (len(scores) == 1 or scores[0][0] - scores[1][0] >= 0.04):
        return scores[0][1]
    return None


def story_record(source_id: str, index: int, title: str, text: str, **extra: Any) -> dict[str, Any]:
    return {
            "id": f"{source_id}-{index + 1}-{slug(title)}",
            "title": clean_title(title),
            "text": clean_story(text),
            "sourceId": source_id,
            **extra,
        }


def tan_stories(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    serial = 0
    for source_index, record in enumerate(records):
        result.append(
            story_record(
                "tanbible",
                serial,
                record.get("title", ""),
                record.get("story", ""),
                sourceRecord=source_index + 1,
            )
        )
        serial += 1
        behind = clean_story(record.get("story_behind", ""))
        if not behind:
            continue
        chunks = re.split(r"\s+~\s*(?=[A-Za-z])", record.get("story_behind", ""))
        for chunk_index, chunk in enumerate(chunks):
            if chunk_index == 0:
                variant_title = record.get("title_behind", record.get("title", ""))
                variant_text = chunk
            else:
                match = re.match(r"\s*([^\n]{1,100}?\(\d+\))\s+(.*)", chunk, flags=re.S)
                variant_title = match.group(1) if match else record.get("title", "")
                variant_text = match.group(2) if match else chunk
            result.append(
                story_record(
                    "tanbible",
                    serial,
                    variant_title,
                    variant_text,
                    sourceRecord=source_index + 1,
                    variant=chunk_index + 2,
                )
            )
            serial += 1
    return result


def build() -> dict[str, Any]:
    hymn_asset = json.loads((ROOT / "assets" / "hymns.json").read_text(encoding="utf-8"))
    hymns = hymn_asset["hymns"]
    grouped: dict[str, dict[str, Any]] = {}
    lookup: dict[str, str] = {}
    lyric_lines: dict[str, list[str]] = defaultdict(list)

    for hymn in hymns:
        key = normalize_title(hymn["title"])
        edition = hymn["version"]
        number = int(hymn["number"])
        record = grouped.setdefault(
            key,
            {
                "id": slug(hymn["title"]),
                "title": hymn["title"],
                "numbers": {"old": [], "new": []},
                "authors": [],
                "composers": [],
                "editions": {"old": [], "new": []},
                "stories": [],
            },
        )
        record["numbers"][edition].append(number)
        reference = {"number": number, "title": hymn["title"]}
        record["editions"][edition].append(reference)
        lookup[f"{edition}:{number}"] = record["id"]
        lyric_lines[key].extend(plain_lyric_lines(hymn["body"]))

    app_titles = {key: record["title"] for key, record in grouped.items()}
    references: dict[tuple[str, int], dict[str, Any]] = {}
    for record in grouped.values():
        for edition in ("old", "new"):
            for reference in record["editions"][edition]:
                references[(edition, reference["number"])] = reference

    for edition, filename, source_id in (
        ("old", "hymnary_chsd1941.csv", "hymnary-chsd1941"),
        ("new", "hymnary_sdah1985.csv", "hymnary-sdah1985"),
    ):
        with (SOURCE_DIR / filename).open(encoding="utf-8-sig", newline="") as handle:
            for row in csv.DictReader(handle):
                try:
                    number = int(row.get("number", ""))
                except ValueError:
                    continue
                reference = references.get((edition, number))
                if reference is not None:
                    reference.update(without_empty(csv_metadata(row, source_id)))

    overrides = json.loads((SOURCE_DIR / "overrides.json").read_text(encoding="utf-8"))
    for key, values in overrides.items():
        edition, number = key.split(":", 1)
        if (edition, int(number)) in references:
            references[(edition, int(number))].update(values)

    for record in grouped.values():
        for edition in ("old", "new"):
            for reference in record["editions"][edition]:
                record["authors"].extend(reference.get("authors", []))
                record["composers"].extend(reference.get("composers", []))
        record["authors"] = merge_people(record["authors"])
        record["composers"] = merge_people(record["composers"])
        record["numbers"]["old"].sort()
        record["numbers"]["new"].sort()

    recovered: list[dict[str, Any]] = []
    faith = json.loads((SOURCE_DIR / "faith.json").read_text(encoding="utf-8"))
    for index, raw in enumerate(faith):
        title = clean_title(raw.get("title", ""))
        match = match_title(title, app_titles)
        story = clean_story(raw.get("story", ""))
        if match:
            story = strip_faith_lyrics(story, title, lyric_lines[match])
        item = story_record(
            "sharefaith",
            index,
            title,
            story,
            rawAttribution=compact_space(raw.get("author", "")),
            sourceRecord=index + 1,
        )
        item["matchedTitleKey"] = match
        recovered.append(item)

    for item in tan_stories(json.loads((SOURCE_DIR / "tanbible.json").read_text(encoding="utf-8"))):
        item["matchedTitleKey"] = match_title(item["title"], app_titles)
        recovered.append(item)

    for item in recovered:
        match = item.pop("matchedTitleKey", None)
        if match:
            grouped[match]["stories"].append(item)

    unmatched = [item for item in recovered if not any(item["id"] == story["id"] for record in grouped.values() for story in record["stories"])]

    records = sorted(grouped.values(), key=lambda item: item["title"].casefold())
    id_by_title = {normalize_title(item["title"]): item["id"] for item in records}
    # The initial grouping key and the displayed title normally normalize the
    # same way; rebuild lookup through IDs to keep the published file explicit.
    for hymn in hymns:
        lookup[f"{hymn['version']}:{hymn['number']}"] = id_by_title[normalize_title(hymn["title"])]

    matched_story_count = sum(len(item["stories"]) for item in records)
    duplicate_log = (SOURCE_DIR / "duplicate-urls-tanbible.txt").read_text(
        encoding="utf-8"
    )
    duplicate_urls = Counter(re.findall(r"<GET (https?://[^>]+)>", duplicate_log))
    return {
            "schemaVersion": 1,
            "description": "Sanitized credits, cross-hymnal numbers, stories, and supplemental source data for the SDA Hymnal app.",
            "sources": [
                {
                    "id": "sharefaith",
                    "name": "ShareFaith Hymns: The Songs and the Stories",
                    "url": "http://www.sharefaith.com/guide/Christian-Music/hymns-the-songs-and-the-stories/articles.html",
                    "kind": "recovered commissioned scrape",
                    "records": len(faith),
                },
                {
                    "id": "tanbible",
                    "name": "TanBible Stories Behind the Hymns",
                    "url": "http://www.tanbible.com/tol_sng/0tol_sng_0menu.htm",
                    "kind": "recovered commissioned scrape",
                    "records": len(json.loads((SOURCE_DIR / "tanbible.json").read_text(encoding="utf-8"))),
                },
                {
                    "id": "hymnary-chsd1941",
                    "name": "Hymnary Church Hymnal 1941 catalog",
                    "url": "https://hymnary.org/hymnal/CHSD1941",
                    "kind": "public catalog metadata",
                },
                {
                    "id": "hymnary-sdah1985",
                    "name": "Hymnary Seventh-day Adventist Hymnal 1985 catalog",
                    "url": "https://hymnary.org/hymnal/sdah1985",
                    "kind": "public catalog metadata",
                },
            ],
            "statistics": {
                "hymnWorks": len(records),
                "hymnReferences": len(hymns),
                "matchedStories": matched_story_count,
                "supplementalStories": len(unmatched),
            },
            "lookup": dict(sorted(lookup.items())),
            "hymns": [publish_hymn(item) for item in records],
            "supplementalStories": unmatched,
            "scrapeDiagnostics": {
                "tanBibleDuplicateRequests": [
                    {"url": url, "count": count}
                    for url, count in sorted(duplicate_urls.items())
                ]
            },
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "assets" / "hymn_metadata.json",
    )
    args = parser.parse_args()
    payload = build()
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    stats = payload["statistics"]
    print(f"Wrote {args.output}: {stats}")


if __name__ == "__main__":
    main()
