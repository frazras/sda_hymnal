"""Precomputed reports. Public projections never include fine dimensions."""
import datetime as dt
import json
from collections import defaultdict
from pathlib import Path

MINIMUM = 20
catalog_path = Path(__file__).with_name('catalog.json')
CATALOG = json.loads(catalog_path.read_text()) if catalog_path.exists() else {}


def songs(rows, metric, limit=20):
    counts = defaultdict(int)
    for row in rows:
        if row['metric'] == metric and row.get('hymn'):
            counts[(row['edition'], int(row['hymn']))] += int(row['count'])
    return [{'edition': edition, 'hymn': hymn, 'title': CATALOG.get(f'{edition}:{hymn}', f'Hymn {hymn}'), 'count': count}
        for (edition, hymn), count in sorted(counts.items(), key=lambda x: (-x[1], x[0]))[:limit]]


def breakdown(rows, field, metric=None, value='count'):
    counts = defaultdict(int)
    for row in rows:
        if (metric is None or row['metric'] == metric) and field in row:
            counts[str(row[field])] += int(row.get(value, 0))
    return [{'label': key, 'count': value} for key, value in sorted(counts.items(), key=lambda x: (-x[1], x[0]))]


def suppress_partition(rows):
    """Hide another cell when subtraction could expose a small remainder."""
    eligible = [r for r in rows if r['contributors'] >= MINIMUM]
    if len(eligible) != len(rows) and eligible:
        hidden = min(eligible, key=lambda r: (r['count'], json.dumps(r, sort_keys=True)))
        eligible = [r for r in eligible if r is not hidden]
    return eligible


def safe_public_rows(rows):
    coarse = [r for r in rows if r.get('view')]
    eligible = [r for r in coarse if r['view'] == 'song' and r['contributors'] >= MINIMUM]
    for view in ('time', 'weekday'):
        eligible.extend(suppress_partition([r for r in coarse if r['view'] == view]))
    countries = defaultdict(list)
    for row in coarse:
        if row['view'] == 'country_song':
            countries[(row['edition'], row['hymn'])].append(row)
    for partition in countries.values():
        eligible.extend(suppress_partition(partition))
    return eligible


def public_report(weeks, monday, generated):
    safe = {week: safe_public_rows(rows) for week, rows in weeks.items()
        if monday - dt.timedelta(weeks=8) <= dt.date.fromisoformat(week) < monday}
    periods = {}
    for length in (1, 4, 8):
        start = monday - dt.timedelta(weeks=length)
        rows = [r for w, rs in safe.items() if w >= str(start) for r in rs]
        song_rows = [r for r in rows if r['view'] == 'song']
        country_rows = [r for r in rows if r['view'] == 'country_song']
        countries = sorted({r['country'] for r in country_rows if r['country'] != 'ZZ'})
        periods[str(length)] = {'start': str(start), 'end': str(monday - dt.timedelta(days=1)),
            'top_songs': songs(song_rows, 'hymn_open'), 'repeat_songs': songs(song_rows, 'hymn_repeat'),
            'favorites': songs(song_rows, 'favorite_add'),
            'times': breakdown([r for r in rows if r['view'] == 'time'], 'time'),
            'weekdays': breakdown([r for r in rows if r['view'] == 'weekday'], 'weekday'),
            'countries': [{'country': country, 'songs': songs([r for r in country_rows if r['country'] == country], 'hymn_open', 10)} for country in countries]}
    return {'schema': 2, 'generated': generated, 'minimum_contributors': MINIMUM,
        'periods': periods, 'weeks': [], 'measurement': 'published weekly activity, not unique people'}


def admin_period(rows, song_limit=20):
    totals = defaultdict(int)
    durations = defaultdict(int)
    for row in rows:
        totals[row['metric']] += int(row['count'])
        durations[row['metric']] += int(row['total'])
    errors = [r for r in rows if r['metric'] in ('diagnostic', 'play_error', 'video_error', 'cache_error')]
    version_rows = defaultdict(lambda: {'opens': 0, 'sessions': 0, 'play_attempts': 0, 'play_errors': 0, 'diagnostics': 0})
    for row in rows:
        version = version_rows[(row.get('platform', 'unknown'), row.get('version', 'unknown'))]
        key = {'hymn_open': 'opens', 'app_session': 'sessions', 'play_attempt': 'play_attempts', 'play_error': 'play_errors', 'diagnostic': 'diagnostics'}.get(row['metric'])
        if key:
            version[key] += int(row['count'])
    return {'totals': dict(totals), 'durations': dict(durations),
        'top_songs': songs(rows, 'hymn_open', song_limit), 'repeat_songs': songs(rows, 'hymn_repeat', song_limit), 'favorites': songs(rows, 'favorite_add', song_limit),
        'features': breakdown(rows, 'variant', 'screen_view'),
        'screen_seconds': breakdown(rows, 'variant', 'screen_seconds', 'total'),
        'sources': breakdown(rows, 'variant', 'hymn_open'),
        'search_results': breakdown(rows, 'variant', 'search_results'),
        'errors': breakdown([dict(r, category=r['metric'] + (': ' + r['variant'] if r.get('variant') else '')) for r in errors], 'category'), 'countries': breakdown(rows, 'country', 'hymn_open'),
        'times': breakdown(rows, 'time', 'hymn_open'), 'weekdays': breakdown(rows, 'weekday', 'hymn_open'),
        'settings': breakdown([dict(r, choice=r['metric'].removeprefix('setting_') + ': ' + r.get('variant', '')) for r in rows if r['metric'].startswith('setting_')], 'choice'),
        'versions': [{'platform': platform, 'version': version, **values} for (platform, version), values in sorted(version_rows.items())]}


def compile_admin_week(rows):
    # Keep complete song totals until period ranking: a song outside each
    # week's top 20 can still rank highly over a longer reporting period.
    fine = [r for r in rows if not r.get('view')]
    return {platform: admin_period([r for r in fine if platform == 'all' or r.get('platform') == platform], 1400)
            for platform in ('all', 'android', 'ios')}


def merge_admin(reports):
    merged = admin_period([])
    for field in ('totals', 'durations'):
        for report in reports:
            for key, value in report[field].items():
                merged[field][key] = merged[field].get(key, 0) + value
    for field, metric in (('top_songs', 'hymn_open'), ('repeat_songs', 'hymn_repeat'), ('favorites', 'favorite_add')):
        merged[field] = songs([dict(row, metric=metric) for report in reports for row in report[field]], metric)
    for field in ('features', 'screen_seconds', 'sources', 'search_results', 'errors', 'countries', 'times', 'weekdays', 'settings'):
        merged[field] = breakdown([row for report in reports for row in report[field]], 'label')
    versions = {}
    for report in reports:
        for row in report['versions']:
            key = (row['platform'], row['version'])
            value = versions.setdefault(key, dict(platform=key[0], version=key[1]))
            for field in ('opens', 'sessions', 'play_attempts', 'play_errors', 'diagnostics'):
                value[field] = value.get(field, 0) + row[field]
    merged['versions'] = [versions[k] for k in sorted(versions)]
    return merged


def admin_report(weeks, monday, generated, compiled=False):
    if not compiled:
        weeks = {week: compile_admin_week(rows) for week, rows in weeks.items()}
    periods = {}
    for period, length in (('current', 0), ('1', 1), ('4', 4), ('8', 8)):
        start = monday - dt.timedelta(weeks=length)
        end = monday if length else monday + dt.timedelta(weeks=1)
        weeks_in_period = {w: rs for w, rs in weeks.items() if str(start) <= w < str(end)}
        platforms = {}
        for platform in ('all', 'android', 'ios'):
            selected = {w: rs[platform] for w, rs in weeks_in_period.items()}
            report = merge_admin(list(selected.values()))
            report['weekly'] = [{'week': str(start + dt.timedelta(weeks=i)), 'count': selected.get(str(start + dt.timedelta(weeks=i)), {}).get('totals', {}).get('hymn_open', 0)} for i in range(length or 1)]
            platforms[platform] = report
        periods[period] = {'start': str(start), 'end': str(end - dt.timedelta(days=1)), 'partial': length == 0, 'platforms': platforms}
    return {'schema': 1, 'generated': generated, 'periods': periods}
