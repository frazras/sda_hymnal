import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';

/// Integrity guards on the shipped hymn database, and on the number-keyed
/// lookups that read it.
///
/// These exist because of a defect inherited from the original 2016 Ionic
/// app and shipped in every release since: its `threeonefour` record held a
/// mislabeled, truncated copy of hymn 313 instead of hymn 314, so
/// assets/hymns.json carried 313 twice and 314 not at all. Combined with
/// positional `list[number - 1]` lookups, typing 314 opened a one-verse stub
/// titled 313, and paging forward from 313 resolved to that same row again —
/// a dead end the reader could only escape with Back.
void main() {
  final hymns =
      HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync());
  final newHymns = [
    for (final h in hymns)
      if (h.version == 'new') h,
  ];
  final oldHymns = [
    for (final h in hymns)
      if (h.version == 'old') h,
  ];

  group('hymns.json integrity', () {
    test('no hymnal repeats a number', () {
      for (final (label, list) in [('new', newHymns), ('old', oldHymns)]) {
        final seen = <int>{};
        final dupes = <int>{};
        for (final h in list) {
          if (!seen.add(h.number)) dupes.add(h.number);
        }
        expect(dupes, isEmpty, reason: '$label hymnal repeats $dupes');
      }
    });

    test('the Old Hymnal is complete, 1..703', () {
      final nums = {for (final h in oldHymns) h.number};
      expect([for (var n = 1; n <= 703; n++) if (!nums.contains(n)) n],
          isEmpty);
    });

    test('the New Hymnal is complete, 1..695', () {
      // 314 was absent from every release since 2016 — the source data the
      // app inherited held a mislabeled, truncated copy of 313 in its slot.
      // The printed 1985 hymnal settled it: 314 is a genuine one-stanza
      // second setting of "Just as I Am", ending "I come, I come".
      // Restored 2026-08-17 from a photograph of the page.
      final nums = {for (final h in newHymns) h.number};
      expect([for (var n = 1; n <= 695; n++) if (!nums.contains(n)) n],
          isEmpty);
    });

    test('every hymn carries a title and a body', () {
      for (final h in hymns) {
        expect(h.title.trim(), isNotEmpty, reason: '${h.version} ${h.number}');
        expect(h.body.trim(), isNotEmpty,
            reason: '${h.version} ${h.number} "${h.title}"');
      }
    });

    test('no verse repeats a word back to back', () {
      // Cheap, near-zero false positives, and it caught four real defects
      // reported by users for years: 336 "from the the grave" and 384
      // "Till we we rise", each in BOTH hymnals' copy of the hymn.
      // "ten thousand thousand" (255) is genuine poetic repetition.
      final doubled = RegExp(r'\b(\w+) \1\b', caseSensitive: false);
      for (final h in hymns) {
        for (final m in doubled.allMatches(h.body)) {
          if (m.group(1)!.toLowerCase() == 'thousand') continue;
          fail('${h.version} ${h.number} "${h.title}" repeats a word: '
              '"${m.group(0)}"');
        }
      }
    });

    test('verse numbering runs 1..k with no gap or repeat', () {
      // 254 shipped as 1,2,4,4 for years — content complete, label wrong.
      final marker = RegExp(r'<b>(\d+)</b>');
      for (final h in hymns) {
        final nums = [
          for (final m in marker.allMatches(h.body)) int.parse(m.group(1)!),
        ];
        if (nums.isEmpty) continue; // service music carries no numbering
        expect(nums, [for (var i = 1; i <= nums.length; i++) i],
            reason: '${h.version} ${h.number} "${h.title}" verse markers');
      }
    });

    test('no hymn body is a truncated copy of another', () {
      // The stub that caused this bug held only verse 1 of the hymn it
      // duplicated, so its body was a strict PREFIX of the full record's.
      // Length alone cannot catch that — the book carries genuine 78-char
      // responses — and identical bodies are legitimate, since the same
      // words appear under several numbers with different tunes (Old 118,
      // 119 and 120 are three settings of "When I Survey the Wondrous
      // Cross"). A strict prefix under the same title is the truncation
      // signature.
      final byTitle = <String, List<Hymn>>{};
      for (final h in hymns) {
        (byTitle['${h.version}|${h.title.trim()}'] ??= []).add(h);
      }
      for (final group in byTitle.values) {
        if (group.length < 2) continue;
        for (final a in group) {
          for (final b in group) {
            if (identical(a, b)) continue;
            final short = a.body.trim();
            final long = b.body.trim();
            expect(short != long && long.startsWith(short), isFalse,
                reason: '${a.version} ${a.number} "${a.title}" is a '
                    'truncated copy of ${b.number}');
          }
        }
      }
    });
  });

  group('number-keyed lookup', () {
    test('finds a hymn by its number, not its position', () {
      expect(hymnByNumber(newHymns, 313)?.title, 'Just as I Am');
      // 315 sits at index 313 now that 314 is absent — positional indexing
      // would return the wrong hymn here.
      expect(hymnByNumber(newHymns, 315)?.number, 315);
      expect(hymnByNumber(newHymns, 695)?.number, 695);
      expect(hymnByNumber(oldHymns, 703)?.number, 703);
    });

    test('returns null for numbers the hymnal does not carry', () {
      expect(hymnByNumber(newHymns, 0), isNull);
      expect(hymnByNumber(newHymns, 696), isNull);
      expect(hymnByNumber(oldHymns, 704), isNull);
    });

    test('313, 314 and 315 are three distinct hymns', () {
      // Seven users reported this trio freezing: 314 was missing and 313
      // was duplicated as a stub, so paging forward from 313 returned the
      // same row forever. All three must now be distinct and reachable.
      final h313 = hymnByNumber(newHymns, 313)!;
      final h314 = hymnByNumber(newHymns, 314)!;
      final h315 = hymnByNumber(newHymns, 315)!;
      expect(h313.body, isNot(h314.body));
      expect(h314.body, isNot(h315.body));
      expect(adjacentHymn(newHymns, 313, 1, 695)?.number, 314);
      expect(adjacentHymn(newHymns, 314, 1, 695)?.number, 315);
      expect(adjacentHymn(newHymns, 315, -1, 695)?.number, 314);
    });

    test('paging steps over a gap rather than stalling', () {
      // Both books are complete today, so this guards the mechanism: from
      // any hymn, paging forward must strictly advance or stop.
      for (final (list, max) in [(newHymns, 695), (oldHymns, 703)]) {
        for (final h in list) {
          final next = adjacentHymn(list, h.number, 1, max);
          if (next != null) expect(next.number, greaterThan(h.number));
        }
      }
    });

    test('paging stops at the ends of each hymnal', () {
      expect(adjacentHymn(newHymns, 1, -1, 695), isNull);
      expect(adjacentHymn(newHymns, 695, 1, 695), isNull);
      expect(adjacentHymn(oldHymns, 703, 1, 703), isNull);
    });

    test('every hymn in both books is reachable by paging from the first', () {
      for (final (list, max) in [(newHymns, 695), (oldHymns, 703)]) {
        var hymn = hymnByNumber(list, 1);
        var visited = 1;
        while (hymn != null) {
          final next = adjacentHymn(list, hymn.number, 1, max);
          if (next != null) {
            // Paging must always advance, or the reader is trapped.
            expect(next.number, greaterThan(hymn.number));
            visited++;
          }
          hymn = next;
        }
        expect(visited, list.length);
      }
    });
  });
}
