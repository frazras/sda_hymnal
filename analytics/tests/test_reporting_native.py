import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'server'))
import reporting

class NativeReportingTest(unittest.TestCase):
    def row(self, book, count, **extra):
        return dict(metric='hymn_open', edition='', book_id=book, hymn=303,
                    count=count, total=0, **extra)

    def test_same_number_in_different_books_stays_distinct(self):
        rows = [self.row('sda-es-2009', 4), self.row('sda-es-1962', 3)]
        with patch.dict(reporting.CATALOG, {'sda-es-2009:303': 'Sublime Gracia'}):
            songs = reporting.songs(rows, 'hymn_open')
        self.assertEqual([s['book_id'] for s in songs], ['sda-es-2009', 'sda-es-1962'])
        self.assertEqual(songs[0]['title'], 'Sublime Gracia')

    def test_english_native_and_legacy_merge_with_legacy_output(self):
        native = self.row('sda-en-1985', 4)
        legacy = dict(native, edition='new', count=3)
        del legacy['book_id']
        songs = reporting.songs([native, legacy], 'hymn_open')
        self.assertEqual(len(songs), 1)
        self.assertEqual(songs[0]['count'], 7)
        self.assertEqual(songs[0]['edition'], 'new')
        self.assertNotIn('book_id', songs[0])

    def test_country_suppression_partitions_are_book_specific(self):
        rows = [self.row('sda-es-2009', 20, view='country_song', country='JM', contributors=20),
                self.row('sda-es-1962', 1, view='country_song', country='JM', contributors=1)]
        self.assertEqual(reporting.safe_public_rows(rows), [rows[0]])

    def test_legacy_public_report_retains_english_ranking(self):
        import datetime as dt
        rows = [self.row('sda-es-2009', 50, view='song', contributors=20),
                dict(self.row('sda-en-1985', 20, view='song', contributors=20), edition='new')]
        weeks = {'2026-08-31': rows}
        native = reporting.public_report(weeks, dt.date(2026, 9, 7), 'now')
        legacy = reporting.public_report(weeks, dt.date(2026, 9, 7), 'now', legacy=True)
        self.assertEqual(len(native['periods']['1']['top_songs']), 2)
        songs = legacy['periods']['1']['top_songs']
        self.assertEqual(len(songs), 1)
        self.assertEqual(songs[0]['edition'], 'new')
