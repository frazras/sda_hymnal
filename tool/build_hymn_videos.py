#!/usr/bin/env python3
"""Build deterministic in-app YouTube video assignments for both hymnals."""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "tool" / "data" / "hymn_metadata_sources"

VIDEO_TITLE_ALIASES = {
    "all hail the power of jesus": "all hail the power of jesus name",
    "it is well": "it is well with my soul",
    "great is thy faithfulness": "great is thy faithfulness",
    "this is my fathers world": "this is my fathers world",
    "blessed assurance": "blessed assurance jesus is mine",
    "christ arose": "low in the grave he lay",
    "silent night": "silent night holy night",
    "the ninety and nine": "there were ninety and nine",
    "throw out the life line": "throw out the lifeline",
    "what a friend": "what a friend we have in jesus",
}


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value or "")
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.casefold().replace("&", " and ").replace("'", "")
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", value)).strip()


def cleaned_video_title(value: str) -> str:
    value = re.sub(r"^\s*(?:hymn\s*)?#?\d{1,3}\s*(?:v\.?\s*\d+)?\s*[-.:]?\s*", "", value, flags=re.I)
    value = re.sub(r"^\s*SDA\s+Hymn(?:al)?\s*[-.:]?\s*", "", value, flags=re.I)
    value = re.split(r"\s*(?:\|\||//|~|#)\s*", value, maxsplit=1)[0]
    value = re.sub(r"\s*\((?:singing\s+w/?\s*lyrics|with\s+lyrics|lyrics|saxophone|cover)\)\s*$", "", value, flags=re.I)
    value = re.sub(r"\s+(?:sda\s+hymn(?:al)?).*?$", "", value, flags=re.I)
    return re.sub(r"\s+", " ", value).strip(" -–—")


def numbered_title(value: str) -> tuple[int, str] | None:
    match = re.match(r"^\s*(\d{1,3})\b", value)
    if match is None:
        return None
    return int(match.group(1)), cleaned_video_title(value)


def title_match(title: str, work_titles: dict[str, str]) -> str | None:
    candidate = normalize(cleaned_video_title(title))
    candidate = VIDEO_TITLE_ALIASES.get(candidate, candidate)
    if candidate in work_titles:
        return candidate
    scores = sorted(
        ((SequenceMatcher(None, candidate, key).ratio(), key) for key in work_titles),
        reverse=True,
    )
    if scores and scores[0][0] >= 0.93 and (len(scores) == 1 or scores[0][0] - scores[1][0] >= 0.05):
        return scores[0][1]
    return None


def source_videos(filename: str, channel: str, channel_id: str, priority: int) -> list[dict[str, Any]]:
    rows = json.loads((SOURCE_DIR / filename).read_text(encoding="utf-8"))
    return [
        {
            "youtubeVideoId": row["id"],
            "title": row["title"],
            "channel": channel,
            "channelId": channel_id,
            "priority": priority,
        }
        for row in rows
        if row.get("id") and row.get("title")
    ]


def build() -> dict[str, Any]:
    metadata = json.loads((ROOT / "assets" / "hymn_metadata.json").read_text(encoding="utf-8"))
    works = metadata["hymns"]
    work_by_id = {work["id"]: work for work in works}
    work_titles = {normalize(work["title"]): work["id"] for work in works}

    amazing = source_videos(
        "youtube_amazingworshiptv.json",
        "Amazing Worship TV",
        "UCx4IY_thLXSbl7dCcr0veug",
        1,
    )
    melissa = source_videos(
        "youtube_melissaoretade.json",
        "Melissa Oretade",
        "UCDG3r9PVHUUGpJJyASkT0jw",
        2,
    )
    hymns_channel = source_videos(
        "youtube_thehymnschannel.json",
        "The Hymns Channel",
        "UCoLQgEDH3W-pkWzCczfLxng",
        3,
    )

    amazing_by_work: dict[str, dict[str, Any]] = {}
    for video in amazing:
        matched_title = title_match(video["title"], work_titles)
        if matched_title is not None:
            amazing_by_work.setdefault(work_titles[matched_title], video)

    numbered: dict[int, dict[str, Any]] = {}
    fallback_by_work: dict[str, dict[str, Any]] = {}
    for video in [*melissa, *hymns_channel]:
        parsed = numbered_title(video["title"])
        if parsed is not None and 1 <= parsed[0] <= 695:
            numbered.setdefault(parsed[0], video)
        matched_title = title_match(video["title"], work_titles)
        if matched_title is not None:
            fallback_by_work.setdefault(work_titles[matched_title], video)

    searched = json.loads((SOURCE_DIR / "youtube_search_fallbacks.json").read_text(encoding="utf-8"))
    searched_by_work = {
        work_id: {
            "youtubeVideoId": value["youtubeVideoId"],
            "title": value["title"],
            "channel": value["channel"],
            "channelId": value.get("channelId", ""),
            "priority": 4,
        }
        for work_id, value in searched.items()
        if value.get("youtubeVideoId")
    }

    assignments: dict[str, dict[str, Any]] = {}
    work_video: dict[str, dict[str, Any]] = {}
    for work in works:
        video = amazing_by_work.get(work["id"])
        if video is None:
            for number in work["numbers"]["new"]:
                if number in numbered:
                    video = numbered[number]
                    break
        video = video or fallback_by_work.get(work["id"]) or searched_by_work.get(work["id"])
        if video is not None:
            work_video[work["id"]] = video

    for reference, work_id in metadata["lookup"].items():
        video = work_video.get(work_id)
        if video is not None:
            assignments[reference] = video

    videos = {
        video["youtubeVideoId"]: video
        for video in assignments.values()
    }
    unmatched_work_ids = [work["id"] for work in works if work["id"] not in work_video]
    unmatched_references = [
        reference
        for reference, work_id in metadata["lookup"].items()
        if work_id in unmatched_work_ids
    ]
    preferred_references = sum(
        1 for video in assignments.values() if video["channel"] == "Amazing Worship TV"
    )

    return {
        "schemaVersion": 1,
        "description": "YouTube IFrame video assignments for in-app hymn playback.",
        "sources": [
            {
                "id": "amazing-worship-tv",
                "channel": "Amazing Worship TV",
                "channelId": "UCx4IY_thLXSbl7dCcr0veug",
                "priority": 1,
            },
            {
                "id": "melissa-oretade",
                "channel": "Melissa Oretade",
                "channelId": "UCDG3r9PVHUUGpJJyASkT0jw",
                "priority": 2,
            },
            {
                "id": "the-hymns-channel",
                "channel": "The Hymns Channel",
                "channelId": "UCoLQgEDH3W-pkWzCczfLxng",
                "priority": 3,
            },
            {
                "id": "youtube-search-fallback",
                "channel": "Other YouTube hymn channels",
                "priority": 4,
            },
        ],
        "statistics": {
            "hymnReferences": len(metadata["lookup"]),
            "assignedReferences": len(assignments),
            "preferredChannelReferences": preferred_references,
            "unmatchedReferences": len(unmatched_references),
            "uniqueVideos": len(videos),
        },
        "videos": sorted(videos.values(), key=lambda item: (item["priority"], item["title"].casefold())),
        "lookup": {
            reference: video["youtubeVideoId"]
            for reference, video in sorted(assignments.items())
        },
        "unmatchedWorks": [
            {
                "id": work_id,
                "title": work_by_id[work_id]["title"],
                "numbers": work_by_id[work_id]["numbers"],
            }
            for work_id in unmatched_work_ids
        ],
        "unmatchedReferences": unmatched_references,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "assets" / "hymn_videos.json")
    args = parser.parse_args()
    payload = build()
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.output}: {payload['statistics']}")


if __name__ == "__main__":
    main()
