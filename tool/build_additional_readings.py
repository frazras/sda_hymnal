#!/usr/bin/env python3
"""Build the app's additional-readings asset from verified source data.

The 1985 source is a SQLite database whose `hymns` rows 696-920 contain
the worship aids and whose `verses` rows preserve the printed responsive
paragraphs in reading order.  The optional 1941 source is a reviewed JSON
file produced from the locally archived hymnal pages.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path


NEW_FIRST = 696
NEW_LAST = 920


def _split_name(name: str, category: str) -> tuple[str, str]:
    if category in {"Scripture Readings", "Canticles and Prayers"}:
        title, separator, reference = name.rpartition(" - ")
        if separator:
            return title.strip(), reference.strip()
    if category in {
        "Calls to Worship",
        "Words of Assurance",
        "Offertory Sentences",
        "Benedictions",
    }:
        return category[:-1] if category.endswith("s") else category, name.strip()
    return name.strip(), ""


def extract_new(sqlite_path: Path) -> list[dict]:
    connection = sqlite3.connect(sqlite_path)
    connection.row_factory = sqlite3.Row
    try:
        rows = connection.execute(
            """
            SELECT h.id, h.name, c.name AS category
            FROM hymns h
            JOIN categories c ON c.id = h.categoryId
            WHERE h.id BETWEEN ? AND ?
            ORDER BY h.id
            """,
            (NEW_FIRST, NEW_LAST),
        ).fetchall()
        if len(rows) != NEW_LAST - NEW_FIRST + 1:
            raise ValueError(f"Expected 225 new-hymnal readings, found {len(rows)}")

        readings: list[dict] = []
        for row in rows:
            number = int(row["id"])
            category = str(row["category"]).strip()
            # The source database accidentally leaves 907 in the offertory
            # group; the printed hymnal begins Benedictions at 907.
            if number == 907:
                category = "Benedictions"
            title, reference = _split_name(str(row["name"]), category)
            segments = connection.execute(
                """
                SELECT sequence, text
                FROM verses
                WHERE hymnId = ?
                ORDER BY sequence
                """,
                (number,),
            ).fetchall()
            if not segments:
                raise ValueError(f"Reading {number} has no text")
            readings.append(
                {
                    "id": f"new-{number}",
                    "edition": "new",
                    "order": number - NEW_FIRST + 1,
                    "number": number,
                    "title": title,
                    "category": category,
                    "scriptureReference": reference,
                    "segments": [
                        {
                            "role": "leader" if index % 2 == 0 else "congregation",
                            "text": str(segment["text"])
                            .replace("\r\n", "\n")
                            .replace("\r", "\n"),
                        }
                        for index, segment in enumerate(segments)
                    ],
                }
            )
        return readings
    finally:
        connection.close()


def load_old(reviewed_json: Path | None) -> list[dict]:
    if reviewed_json is None:
        return []
    decoded = json.loads(reviewed_json.read_text(encoding="utf-8"))
    readings = decoded["readings"] if isinstance(decoded, dict) else decoded
    if len(readings) != 53:
        raise ValueError(f"Expected 53 old-hymnal readings, found {len(readings)}")
    return readings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--new-sqlite", required=True, type=Path)
    parser.add_argument("--old-reviewed-json", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    readings = extract_new(args.new_sqlite) + load_old(args.old_reviewed_json)
    payload = {
        "schemaVersion": 1,
        "sourceFingerprint": hashlib.sha256(
            args.new_sqlite.read_bytes()
        ).hexdigest(),
        "readings": readings,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
