#!/usr/bin/env python3
"""Download and validate pinned recordings (network; requires macOS afinfo).

Each selected file is fetched once from the pinned raw.githubusercontent.com URL
the app streams, into a resumable scratch cache (default tmp/recording_audit,
ignored by Git). A file passes when its byte count and Git blob SHA-1 match the
catalog, it carries an M4A 'ftyp' box, and afinfo reports a positive duration.
Fully validated collections are merged into tool/data/recording_audit.json;
files that never validate are listed and make the exit status nonzero.
Throttled or failed requests back off exponentially before retrying.
Replaces tool/validate_spanish_recordings.py; the full catalog is about 4.5 GiB.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import random
import re
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'tool/data/recording_sources.json'
CHECKS = ['expected byte count', 'pinned Git blob SHA-1', 'M4A ftyp header', 'afinfo positive duration']
RETRYABLE = {403, 408, 425, 429, 500, 502, 503, 504}


def blob_sha1(data):
    return hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()


def source_url(catalog, item):
    return ('https://raw.githubusercontent.com/' + catalog['repository'] + '/'
            + catalog['revision'] + '/' + urllib.parse.quote(item['path']))


class Throttle:
    """Shared pause so one throttled response slows every worker."""

    def __init__(self):
        self._lock = threading.Lock()
        self._until = 0.0

    def wait(self):
        while True:
            with self._lock:
                remaining = self._until - time.monotonic()
            if remaining <= 0:
                return
            time.sleep(min(remaining, 5))

    def pause(self, seconds):
        with self._lock:
            self._until = max(self._until, time.monotonic() + seconds)


def check_audio(path, item):
    data = path.read_bytes()
    if len(data) != item['bytes']:
        raise ValueError(f'expected {item["bytes"]} bytes, got {len(data)}')
    if blob_sha1(data) != item['gitBlobSha1']:
        raise ValueError('Git blob SHA-1 mismatch')
    if data[4:8] != b'ftyp':
        raise ValueError('missing M4A ftyp header')
    info = subprocess.run(['afinfo', str(path)], capture_output=True, text=True, timeout=120)
    match = re.search(r'estimated duration: ([0-9.]+) sec', info.stdout)
    if info.returncode != 0 or not match or float(match[1]) <= 0:
        raise ValueError('afinfo reports no positive duration')
    return float(match[1])


def fetch(url, destination, item, throttle, attempts, stats):
    # Keep the audio extension so afinfo identifies the staged file's type.
    part = destination.with_name(destination.stem + '.part' + destination.suffix)
    delay = 2.0
    for attempt in range(1, attempts + 1):
        throttle.wait()
        wait = delay
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'sdahymnal-recording-audit'})
            with urllib.request.urlopen(request, timeout=60) as response, open(part, 'wb') as out:
                received = 0
                while chunk := response.read(1 << 16):
                    received += len(chunk)
                    if received > item['bytes']:
                        raise ValueError('response exceeds the pinned size')
                    out.write(chunk)
            duration = check_audio(part, item)
            part.replace(destination)
            stats.add(downloaded=item['bytes'])
            return duration
        except urllib.error.HTTPError as error:
            if error.code not in RETRYABLE or attempt == attempts:
                raise
            header = error.headers.get('Retry-After', '')
            wait = max(delay, float(header)) if header.isdigit() else delay
            if error.code in (403, 429):
                throttle.pause(min(wait, 300))
            reason = f'HTTP {error.code}'
        except (urllib.error.URLError, TimeoutError, ConnectionError, ValueError, OSError) as error:
            if attempt == attempts:
                raise
            reason = str(error) or type(error).__name__
        finally:
            part.unlink(missing_ok=True)
        stats.add(retries=1)
        print(f'Retry {attempt}/{attempts - 1} in {wait:.0f}s for {item["path"]}: {reason}', flush=True)
        time.sleep(min(wait, 300) + random.uniform(0, 1))
        delay = min(delay * 2, 120)
    raise RuntimeError('unreachable')


class Stats:
    def __init__(self):
        self._lock = threading.Lock()
        self.values = dict(downloaded=0, reused=0, retries=0)

    def add(self, **counts):
        with self._lock:
            for key, value in counts.items():
                self.values[key] += value


def validate(catalog, collection, item, cache, throttle, attempts, stats):
    destination = cache / collection['bookId'] / collection['medium'] / f'{int(item["itemId"]):03d}.m4a'
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        try:
            duration = check_audio(destination, item)
            stats.add(reused=item['bytes'])
            return duration
        except (ValueError, OSError, subprocess.SubprocessError):
            destination.unlink()
    return fetch(source_url(catalog, item), destination, item, throttle, attempts, stats)


def merge_audit(path, catalog, selected, results, failed, today):
    audit = json.loads(path.read_text()) if path.exists() else {}
    if audit.get('revision') != catalog['revision'] or audit.get('repository') != catalog['repository']:
        audit = {}
    blocks = {(b['bookId'], b['medium']): b for b in audit.get('collections', [])}
    for collection in selected:
        identity = (collection['bookId'], collection['medium'])
        if identity in failed:
            continue
        blocks[identity] = dict(bookId=identity[0], medium=identity[1], validatedOn=today, items=[
            dict(itemId=item['itemId'], durationSeconds=results[identity + (item['itemId'],)],
                 gitBlobSha1=item['gitBlobSha1']) for item in collection['items']])
    order = [(c['bookId'], c['medium']) for c in catalog['collections']]
    merged = dict(schemaVersion=2, repository=catalog['repository'], revision=catalog['revision'],
                  checks=CHECKS, collections=[blocks[i] for i in order if i in blocks])
    path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--book', action='append', help='limit to this book ID (repeatable)')
    parser.add_argument('--medium', action='append', choices=['instrumentalRecording', 'sungRecording'],
                        help='limit to this medium (repeatable)')
    parser.add_argument('--collection', action='append', metavar='BOOK:MEDIUM',
                        help='limit to this exact collection, e.g. sda-pt-1996:sungRecording (repeatable)')
    parser.add_argument('--cache', type=Path, default=ROOT / 'tmp/recording_audit')
    parser.add_argument('--audit', type=Path, default=ROOT / 'tool/data/recording_audit.json')
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--attempts', type=int, default=8)
    parser.add_argument('--limit', type=int,
                        help='smoke test: check only the first N files per collection; the audit is not updated')
    args = parser.parse_args()
    catalog = json.loads(SOURCES.read_text())
    selected = [c for c in catalog['collections']
                if (not args.book or c['bookId'] in args.book)
                and (not args.medium or c['medium'] in args.medium)
                and (not args.collection or f"{c['bookId']}:{c['medium']}" in args.collection)]
    if not selected:
        raise SystemExit('No recording collections match the selection')
    jobs = [(c, item) for c in selected for item in c['items'][:args.limit]]
    total = sum(item['bytes'] for _, item in jobs)
    print(f'Validating {len(jobs)} files ({total / 2**30:.2f} GiB) from {len(selected)} collections', flush=True)
    throttle, stats, results, failures = Throttle(), Stats(), {}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(validate, catalog, c, item, args.cache, throttle, args.attempts, stats): (c, item)
                   for c, item in jobs}
        for done, future in enumerate(concurrent.futures.as_completed(futures), 1):
            collection, item = futures[future]
            identity = (collection['bookId'], collection['medium'], item['itemId'])
            try:
                results[identity] = future.result()
            except Exception as error:  # report every file that never validates
                failures.append(dict(bookId=identity[0], medium=identity[1], itemId=identity[2],
                                     path=item['path'], error=str(error) or type(error).__name__))
                print(f'FAILED {item["path"]}: {failures[-1]["error"]}', flush=True)
            if done % 50 == 0 or done == len(jobs):
                values = stats.values
                print(f'Validated {done - len(failures)}/{len(jobs)}; downloaded '
                      f'{values["downloaded"] / 2**20:.0f} MiB, reused {values["reused"] / 2**20:.0f} MiB, '
                      f'retries {values["retries"]}', flush=True)
    failed = {(f['bookId'], f['medium']) for f in failures}
    if args.limit is None:
        merge_audit(args.audit, catalog, selected, results, failed, datetime.date.today().isoformat())
    for collection in selected:
        identity = (collection['bookId'], collection['medium'])
        checked = len(collection['items'][:args.limit])
        bad = sum(1 for f in failures if (f['bookId'], f['medium']) == identity)
        print(f'{identity[0]} {identity[1]}: {checked - bad}/{checked} validated, '
              f'{len(collection["missingItemIds"])} declared gaps, {collection["totalBytes"]} bytes', flush=True)
    if failures:
        print(json.dumps(failures, ensure_ascii=False, indent=2))
        raise SystemExit(f'{len(failures)} recordings did not validate')


if __name__ == '__main__':
    main()
