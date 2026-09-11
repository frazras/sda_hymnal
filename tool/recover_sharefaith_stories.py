#!/usr/bin/env python3
"""Recover complete ShareFaith story text from archived source pages.

The commissioned JSON lost text contained by inline HTML elements such as
``<i>`` and ``<b>``.  This utility re-extracts the article body while retaining
all descendant text, then writes records in the original JSON order.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import html.parser
import json
import re
import subprocess
import time
import urllib.parse
from difflib import SequenceMatcher
from pathlib import Path


CDX_URL = (
    "https://web.archive.org/cdx/search/cdx?"
    "url=sharefaith.com/guide/Christian-Music/hymns-the-songs-and-the-stories/*"
    "&output=json&filter=statuscode:200&filter=mimetype:text/html"
    "&collapse=urlkey&fl=original,timestamp&from=2010&to=2017"
)


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def title_key(value: str) -> str:
    value = urllib.parse.unquote(value).casefold().replace("&", " and ")
    value = re.sub(r"\b(?:the )?song and the story\b", "", value)
    value = re.sub(r"\bthe story\b|\bstory behind the song\b", "", value)
    return compact(re.sub(r"[^a-z0-9]+", " ", value))


class ArticleParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.capture_heading: str | None = None
        self.heading_parts: list[str] = []
        self.headings: dict[str, str] = {"title": "", "h1": "", "h2": ""}
        self.article_stack: list[str] = []
        self.skip_at_depth: int | None = None
        self.article_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag in {"title", "h1", "h2"} and not self.article_stack:
            self.capture_heading = tag
            self.heading_parts = []
        if tag == "div" and attributes.get("id") == "articlebody" and not self.article_stack:
            self.article_stack = ["articlebody"]
            return
        if self.article_stack:
            if tag == "br":
                if self.skip_at_depth is None:
                    self.article_parts.append("\n")
                return
            if tag in {"area", "base", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}:
                return
            self.article_stack.append(tag)
            if self.skip_at_depth is None and (
                tag in {"script", "style", "iframe"}
                or attributes.get("id") == "articlebody-inline"
            ):
                self.skip_at_depth = len(self.article_stack)

    def handle_startendtag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        if self.article_stack and self.skip_at_depth is None and tag == "br":
            self.article_parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if self.capture_heading == tag:
            self.headings[tag] = compact("".join(self.heading_parts))
            self.capture_heading = None
            self.heading_parts = []
        if not self.article_stack:
            return
        if tag == "div" and self.article_stack == ["articlebody"]:
            self.article_stack.clear()
            self.skip_at_depth = None
            return
        if tag not in self.article_stack[1:]:
            return
        reverse_index = self.article_stack[::-1].index(tag)
        match_index = len(self.article_stack) - reverse_index - 1
        del self.article_stack[match_index:]
        if self.skip_at_depth is not None and len(self.article_stack) < self.skip_at_depth:
            self.skip_at_depth = None

    def handle_data(self, data: str) -> None:
        if self.capture_heading:
            self.heading_parts.append(data)
        if self.article_stack and self.skip_at_depth is None:
            self.article_parts.append(data)

    @property
    def title(self) -> str:
        return self.headings["h1"] or self.headings["title"]

    @property
    def author(self) -> str:
        return self.headings["h2"].replace("Composwer ", "Composer ")

    @property
    def story(self) -> str:
        lines = [compact(line) for line in "".join(self.article_parts).splitlines()]
        return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


def fetch(url: str, attempts: int = 4) -> bytes:
    for attempt in range(attempts):
        result = subprocess.run(
            [
                "curl",
                "-fsSL",
                "--max-time",
                "45",
                "--user-agent",
                "Mozilla/5.0",
                url,
            ],
            capture_output=True,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout
        if attempt + 1 == attempts:
            raise RuntimeError(
                f"Could not retrieve {url}: {result.stderr.decode(errors='replace')}"
            )
        else:
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("unreachable")


def parse_article(content: bytes) -> dict[str, str]:
    parser = ArticleParser()
    parser.feed(content.decode("utf-8", errors="replace"))
    if not parser.title or not parser.story:
        raise ValueError("Archived page did not contain a complete article")
    return {"title": parser.title, "author": parser.author, "story": parser.story}


def article_snapshots(cdx_rows: list[list[str]]) -> list[tuple[str, str]]:
    snapshots: list[tuple[str, str]] = []
    for original, timestamp in cdx_rows[1:]:
        filename = urllib.parse.urlsplit(original).path.rsplit("/", 1)[-1]
        if filename in {"articles.html", "articles_2.html", "index.html"}:
            continue
        snapshot = f"https://web.archive.org/web/{timestamp}id_/{original}"
        snapshots.append((original, snapshot))
    if len(snapshots) != 70:
        raise ValueError(f"Expected 70 archived articles, found {len(snapshots)}")
    return snapshots


def recover(
    original_records: list[dict[str, str]],
    snapshots: list[tuple[str, str]],
    cache_directory: Path,
    workers: int,
) -> list[dict[str, str]]:
    cache_directory.mkdir(parents=True, exist_ok=True)

    def load(item: tuple[str, str]) -> dict[str, str]:
        original, snapshot = item
        cache_name = re.sub(
            r"[^a-z0-9.-]+",
            "-",
            urllib.parse.unquote(original.rsplit("/", 1)[-1]).casefold(),
        )
        cache_path = cache_directory / cache_name
        if not cache_path.exists():
            cache_path.write_bytes(fetch(snapshot))
        article = parse_article(cache_path.read_bytes())
        article["sourceUrl"] = original.replace(":80/", "/")
        return article

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        articles = list(executor.map(load, snapshots))

    available = list(articles)
    recovered: list[dict[str, str]] = []
    for original in original_records:
        original_title = original.get("title", "")
        if original_title:
            scores = [
                (SequenceMatcher(None, title_key(original_title), title_key(item["title"])).ratio(), item)
                for item in available
            ]
            score, match = max(scores, key=lambda pair: pair[0])
            if score < 0.72:
                raise ValueError(f"No archived match for {original_title!r}; best score {score:.2f}")
        else:
            original_prefix = title_key(original.get("story", "")[:500])
            scores = [
                (
                    SequenceMatcher(
                        None,
                        original_prefix,
                        title_key(item["story"][:500]),
                    ).ratio(),
                    item,
                )
                for item in available
            ]
            score, match = max(scores, key=lambda pair: pair[0])
            if score < 0.72:
                raise ValueError(
                    f"Could not recover the untitled record; best score {score:.2f}"
                )
        available.remove(match)
        recovered.append(
            {
                "story": match["story"],
                "title": match["title"],
                "author": match["author"],
                "sourceUrl": match["sourceUrl"],
            }
        )
    if available:
        raise ValueError(f"Unmatched archived articles: {[item['title'] for item in available]}")
    return recovered


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cache-directory", required=True, type=Path)
    parser.add_argument("--cdx-json", type=Path)
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()

    cdx_rows = (
        json.loads(args.cdx_json.read_text(encoding="utf-8"))
        if args.cdx_json
        else json.loads(fetch(CDX_URL))
    )
    original_records = json.loads(args.input.read_text(encoding="utf-8"))
    recovered = recover(
        original_records,
        article_snapshots(cdx_rows),
        args.cache_directory,
        args.workers,
    )
    args.output.write_text(
        json.dumps(recovered, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Recovered {len(recovered)} complete ShareFaith stories to {args.output}")


if __name__ == "__main__":
    main()
