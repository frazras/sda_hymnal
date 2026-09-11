#!/usr/bin/env python3
"""Extract the 1941 Church Hymnal responsive readings from reviewed OCR.

The OCR input is generated one printed page at a time with Tesseract TSV.
Paragraph geometry is retained because the book distinguishes the leader
(flush left) from the congregation (bold and indented).
"""

from __future__ import annotations

import argparse
import csv
import difflib
import json
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ReadingInfo:
    title: str
    reference: str


READINGS = (
    ReadingInfo("The Ten Commandments", "Exodus 20:1-17"),
    ReadingInfo("The Three Angels’ Messages", "Revelation 14:6-14"),
    ReadingInfo("Adoration and Praise—1", "Psalms 107:21-36"),
    ReadingInfo("Adoration and Praise—2", "Psalms 24"),
    ReadingInfo("Majesty and Power", "Psalms 19:1-4; Isaiah 42:5-12"),
    ReadingInfo("God’s Power in Nature", "Psalms 8:1-9"),
    ReadingInfo("Love of God", "John 3:16, 17; 1 John 4:7-21"),
    ReadingInfo("Christ’s Sufferings and Death", "Isaiah 53:1-12"),
    ReadingInfo("Christ’s Priesthood", "Hebrews 8:1-4; 9:11-14, 24-28"),
    ReadingInfo("Christ’s Love and Sympathy", "Psalms 103:6, 7, 12-22"),
    ReadingInfo("Christ the Deliverer", "Isaiah 43:1-7, 10-13"),
    ReadingInfo(
        "Christ’s Second Coming",
        "John 14:1-3; Acts 1:10, 11; Matthew 24:42-51",
    ),
    ReadingInfo("The Holy Spirit", "John 14:15-18; 16:7-14; 15:26; 14:26"),
    ReadingInfo("Abiding Presence—1", "Psalms 37:1-11"),
    ReadingInfo("Abiding Presence—2", "Psalms 139:1-12"),
    ReadingInfo(
        "The Holy Scriptures",
        "Deuteronomy 29:29; 2 Peter 1:19-21; 2 Timothy 3:15-17; "
        "John 5:39; Hebrews 4:12, 13; Jeremiah 15:16",
    ),
    ReadingInfo(
        "The Requirements of God",
        "Micah 6:6-8; 7:18-20; Hosea 14:1, 2, 4-6",
    ),
    ReadingInfo("Union With Christ", "John 15:1-16"),
    ReadingInfo("The Good Shepherd", "John 10:1-16"),
    ReadingInfo("Our Protector", "Psalms 91:1-16"),
    ReadingInfo("Goodness of God", "Psalms 107:1-15"),
    ReadingInfo("The Call", "Isaiah 55:1-13"),
    ReadingInfo("Repentance", "Psalms 51:1-17"),
    ReadingInfo("Conversion", "Ephesians 2:1-10; 1 Corinthians 6:9-11"),
    ReadingInfo("Joy of Forgiveness", "Psalms 32"),
    ReadingInfo("Consecration", "Romans 12:1-3, 9-21"),
    ReadingInfo(
        "Peace",
        "Psalms 133:1; Proverbs 12:20; Zechariah 8:19; John 14:27; "
        "James 3:17; Philippians 4:8; 2 Corinthians 13:11",
    ),
    ReadingInfo(
        "Meditation and Prayer",
        "Joshua 1:8; Psalms 1:2; Psalms 119:11, 15, 16, 48, 55, 97-99; "
        "Psalms 19:14",
    ),
    ReadingInfo("Christian Warfare", "Ephesians 6:10-18"),
    ReadingInfo("Exhortations to Godliness", "Colossians 3:1-17"),
    ReadingInfo("The Godly", "Psalms 1"),
    ReadingInfo("The Christian Life", "Matthew 5:3-16"),
    ReadingInfo("Call to Youth", "Ecclesiastes 12:1-7, 13, 14"),
    ReadingInfo("Returning to God", "Luke 15:11-24, 7"),
    ReadingInfo("Seeking the Lost", "Luke 15:3-10"),
    ReadingInfo("Christian Perfection", "Ephesians 4:1-8, 11-16"),
    ReadingInfo("Discipleship", "Romans 6:1, 2, 7-22"),
    ReadingInfo(
        "Work and Duty",
        "1 Timothy 2:8-10; Titus 3:14; 1 Timothy 6:18, 19; Titus 3:8; "
        "2 Corinthians 5:10; Ecclesiastes 12:14",
    ),
    ReadingInfo("Love", "1 Corinthians 13"),
    ReadingInfo("Praise", "Psalms 90:1-12"),
    ReadingInfo("Prayer", "Matthew 6:5-15; 7:7-11"),
    ReadingInfo("Loyalty", "1 John 3:1-10"),
    ReadingInfo(
        "Watchfulness",
        "Exodus 23:13; Deuteronomy 4:9, 23; Mark 13:33-37; Psalms 141:3",
    ),
    ReadingInfo(
        "Hope and Aspiration",
        "Psalms 9:18; 16:8, 9; 33:18; Jeremiah 17:7; Romans 5:2-5; "
        "15:4, 13",
    ),
    ReadingInfo(
        "Guidance",
        "Psalms 21:3; 30:3; Luke 1:79; Isaiah 30:21; "
        "1 Thessalonians 3:11-13",
    ),
    ReadingInfo(
        "The Sabbath",
        "Genesis 2:1-3; Exodus 20:8-11; Isaiah 58:13, 14",
    ),
    ReadingInfo(
        "Baptism",
        "Matthew 28:19, 20; Romans 6:3-7; Galatians 3:26, 27; John 3:5; "
        "1 Corinthians 12:13; 1 Peter 3:21",
    ),
    ReadingInfo("The Lord’s Supper", "Matthew 26:26-30; 1 Corinthians 11:23-31"),
    ReadingInfo(
        "Tithes and Offerings",
        "Matthew 23:23; Leviticus 27:30-33; Malachi 3:8-12",
    ),
    ReadingInfo(
        "Judgment",
        "Psalms 50:3-6; 96:13; Ecclesiastes 3:17; Daniel 7:9, 10; "
        "Matthew 12:36, 37; Hebrews 9:27; Acts 17:31; 1 Peter 4:5, 6",
    ),
    ReadingInfo(
        "Temperance",
        "Titus 2:1-4, 6; Proverbs 20:1; 23:29-32; 1 Corinthians 9:25; "
        "Titus 2:11-13",
    ),
    ReadingInfo("Reward of the Saints—1", "Isaiah 35"),
    ReadingInfo("Reward of the Saints—2", "Revelation 21:1-7; 22:1-5"),
)


def _normalized(value: str) -> str:
    value = value.upper().replace("’", "").replace("—", " ")
    return re.sub(r"[^A-Z0-9]", "", value)


def _join_lines(lines: list[str]) -> str:
    text = ""
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if text.endswith("-"):
            text = text[:-1] + line
        else:
            text += (" " if text else "") + line
    replacements = {
        "| am": "I am",
        "| have": "I have",
        "| was": "I was",
        "| will": "I will",
        "| say": "I say",
        "lam ": "I am ",
        "I .have": "I have",
        "3ut ": "But ",
        "‘The ": "The ",
    }
    for original, corrected in replacements.items():
        text = text.replace(original, corrected)
    text = re.sub(r"\s+([,;:.!?])", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def _load_blocks(tsv_directory: Path) -> list[dict]:
    blocks: list[dict] = []
    for page in range(577, 607):
        path = tsv_directory / f"old-reading-page-{page}.tsv"
        with path.open(encoding="utf-8", newline="") as source:
            rows = [
                row
                for row in csv.DictReader(source, delimiter="\t")
                if row["level"] == "5" and row["text"].strip()
            ]
        block_numbers = list(dict.fromkeys(int(row["block_num"]) for row in rows))
        for block_number in block_numbers:
            words = [row for row in rows if int(row["block_num"]) == block_number]
            line_keys = list(
                dict.fromkeys((row["par_num"], row["line_num"]) for row in words)
            )
            lines = [
                " ".join(
                    row["text"]
                    for row in words
                    if (row["par_num"], row["line_num"]) == line_key
                )
                for line_key in line_keys
            ]
            blocks.append(
                {
                    "page": page,
                    "left": min(int(row["left"]) for row in words),
                    "top": min(int(row["top"]) for row in words),
                    "lines": lines,
                }
            )
    return blocks


def _title_match(lines: list[str], expected: str) -> int:
    expected_key = _normalized(expected)
    combined = ""
    best_score = 0.0
    best_count = 0
    for index, line in enumerate(lines[:3], start=1):
        combined += _normalized(line)
        score = difflib.SequenceMatcher(None, expected_key, combined).ratio()
        if score > best_score:
            best_score = score
            best_count = index
        if score >= 0.96:
            return index
    return best_count if best_score >= 0.90 else 0


def _reference_line_count(lines: list[str], expected: str) -> int:
    expected_key = _normalized(expected)
    combined = ""
    for index, line in enumerate(lines, start=1):
        combined += _normalized(line)
        if combined == expected_key:
            return index
        if not expected_key.startswith(combined):
            break
    return 0


def _role(block: dict) -> str:
    column_origin = 850 if block["left"] >= 800 else 105
    return "congregation" if block["left"] - column_origin >= 30 else "leader"


def extract(tsv_directory: Path) -> dict:
    blocks = _load_blocks(tsv_directory)
    readings: list[dict] = []
    info_index = 0
    current: dict | None = None
    pending_reference = False

    for block in blocks:
        lines = list(block["lines"])
        joined = _join_lines(lines)
        if not joined or re.fullmatch(r"\d{2,3}", joined):
            continue
        if _normalized(joined) == _normalized("Responsive Readings"):
            continue

        if info_index < len(READINGS):
            info = READINGS[info_index]
            title_lines = _title_match(lines, info.title)
            if title_lines:
                current = {
                    "id": f"old-{info_index + 1}",
                    "edition": "old",
                    "order": info_index + 1,
                    "number": None,
                    "title": info.title,
                    "category": "Responsive Readings",
                    "scriptureReference": info.reference,
                    "segments": [],
                }
                readings.append(current)
                info_index += 1
                lines = lines[title_lines:]
                pending_reference = True

        if current is None:
            continue

        if pending_reference:
            reference_lines = _reference_line_count(
                lines, current["scriptureReference"]
            )
            if reference_lines:
                lines = lines[reference_lines:]
                pending_reference = False
            elif lines:
                # Some title blocks end before the separate reference block.
                continue

        text = _join_lines(lines)
        if not text:
            continue
        role = _role(block)
        segments = current["segments"]
        continuation = bool(
            segments
            and (
                text[0].islower()
                or segments[-1]["text"].endswith("-")
                or segments[-1]["text"].endswith((",", ";", ":"))
                and block["top"] < 300
            )
        )
        if continuation:
            prior = segments[-1]["text"]
            if prior.endswith("-"):
                segments[-1]["text"] = prior[:-1] + text
            else:
                segments[-1]["text"] = f"{prior} {text}"
        else:
            segments.append({"role": role, "text": text})

    if info_index != len(READINGS):
        raise ValueError(f"Found {info_index} of {len(READINGS)} reading headings")
    if any(not reading["segments"] for reading in readings):
        raise ValueError("One or more readings contain no responsive text")
    return {"schemaVersion": 1, "readings": readings}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tsv-directory", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    payload = extract(args.tsv_directory)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
