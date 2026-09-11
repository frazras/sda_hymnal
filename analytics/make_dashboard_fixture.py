"""Local browser QA fixture. Never submitted or uploaded to production."""
import datetime as dt
import json
import sys

from deployment import ROOT
sys.path.insert(0, str(ROOT / 'analytics/server'))
import reporting

reporting.CATALOG = {f"{h['version']}:{h['number']}": h['title'] for h in json.loads((ROOT / 'assets/hymns.json').read_text())['hymns']}
today = dt.datetime.now(dt.timezone.utc).date()
monday = today - dt.timedelta(days=today.weekday())
weeks = {}
for i in range(9):
    rows = []
    def add(metric, count, variant='', hymn=0, total=0):
        rows.append(dict(metric=metric, count=count, variant=variant, hymn=hymn, edition='new' if hymn else '',
            total=total, contributors=50, platform='ios', version='4.2.0', country='JM', weekday=6, time='morning'))
    for hymn, count in [(1, 800), (100, 600), (214, 450), (334, 310), (27, 260)]:
        add('hymn_open', count + i * 23, 'keypad', hymn)
        add('hymn_repeat', count // 4, hymn=hymn)
        add('favorite_add', count // 8, hymn=hymn)
    for screen, count in [('numbers', 300), ('search', 210), ('favorites', 130), ('settings', 95), ('statistics', 80)]:
        add('screen_view', count, screen)
        add('screen_seconds', count, screen, total=count * 18)
    add('app_session', 800)
    add('hymn_read_seconds', 1000, hymn=1, total=250000)
    add('play_attempt', 900, 'classic', 1)
    add('play_start', 885); add('play_complete', 740); add('play_error', 15, 'start')
    add('play_start_ms', 885, total=885 * 220)
    add('diagnostic', 2, 'content_load')
    add('search_results', 150, '1_5'); add('search_results', 18, 'zero')
    add('search_select', 142, '1'); add('search_abandon', 20); add('search_refine', 35)
    add('search_select_ms', 142, total=142 * 4200)
    add('setting_theme', 35, 'dark'); add('setting_instrument', 28, 'organ')
    weeks[str(monday - dt.timedelta(weeks=i))] = rows
report = reporting.admin_report(weeks, monday, dt.datetime.now(dt.timezone.utc).isoformat())
(ROOT / 'build/analytics/admin-fixture.json').write_text(json.dumps(report))
print('Local synthetic dashboard fixture generated; no network requests.')
