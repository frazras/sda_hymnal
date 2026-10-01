/// A written melody note. Phrasing changes pitch only: rests, durations and
/// attacks remain intact, so it cannot squeeze an extra run into a held note.
typedef JazzPhraseNote = ({int tick, int end, int pitch});
typedef JazzHarmony = ({int rootPc, String quality});

const _tones = <String, List<int>>{
  '': [0, 4, 7],
  'm': [0, 3, 7],
  '7': [0, 4, 7, 10],
  'maj7': [0, 4, 7, 11],
  'm7': [0, 3, 7, 10],
  'dim': [0, 3, 6],
  'aug': [0, 4, 8],
  'sus4': [0, 5, 7],
};

/// Plans each phrase together, using its melodic contour, all intervening
/// harmony, and its original arrival notes. This is conservative, rule-based
/// interpretation: uncertain harmony or a short phrase keeps the written tune.
List<int> phraseJazzMelody(
  List<JazzPhraseNote> notes, {
  required int division,
  required int beatsPerBar,
  required Map<int, JazzHarmony> harmony,
}) {
  if (notes.isEmpty) return [];
  final pitches = notes.map((n) => n.pitch).toList();
  final bar = division * beatsPerBar;
  var from = 0;
  while (from < notes.length) {
    var to = from + 1;
    while (to < notes.length) {
      final span = notes[to].tick - notes[from].tick;
      final rest = notes[to].tick - notes[to - 1].end;
      // Prefer a breath or sustained cadence near a four-bar phrase; cap at
      // six bars. Boundaries are phrase-relative, never individual bar ends.
      if ((span >= 2 * bar && rest >= division ~/ 2) ||
          (span >= 4 * bar &&
              notes[to - 1].end - notes[to - 1].tick >= division) ||
          span >= 6 * bar) {
        break;
      }
      to++;
    }
    if (notes[to - 1].end - notes[from].tick >= 3 * bar) {
      _plan(notes, from, to, pitches, division, bar, harmony);
    }
    from = to;
  }
  return pitches;
}

void _plan(List<JazzPhraseNote> notes, int from, int to, List<int> result,
    int d, int bar, Map<int, JazzHarmony> harmony) {
  final first = notes[from].tick;
  final last = notes[to - 1].tick;
  // Develop the opening contour in the middle, then return to the original
  // final bar. Repeated motifs receive the same direction, not random turns.
  final opening =
      notes.sublist(from, to).where((n) => n.tick < first + bar).toList();
  final direction = opening.last.pitch >= opening.first.pitch ? 1 : -1;
  var lastChoice = first - 2 * d;
  final candidates = <List<int>>[];
  for (var i = from; i < to; i++) {
    final n = notes[i];
    final choices = <int>[n.pitch];
    final isolated = (i == from || notes[i - 1].end <= n.tick) &&
        (i + 1 == to || n.end <= notes[i + 1].tick);
    if (n.tick >= first + bar &&
        n.tick < last - bar &&
        n.tick - lastChoice >= 2 * d &&
        n.end - n.tick >= 4 * d ~/ 5 &&
        isolated) {
      // An altered sustained note must agree with EVERY chord it crosses.
      Set<int>? allowed;
      for (var beat = n.tick ~/ d; beat <= (n.end - 1) ~/ d; beat++) {
        final chord = harmony[beat];
        if (chord == null || !_tones.containsKey(chord.quality)) {
          allowed = <int>{};
          break;
        }
        final pcs =
            _tones[chord.quality]!.map((v) => (v + chord.rootPc) % 12).toSet();
        allowed = allowed == null ? pcs : allowed.intersection(pcs);
      }
      for (var pitch = n.pitch - 4; pitch <= n.pitch + 4; pitch++) {
        if (pitch != n.pitch &&
            pitch >= 0 &&
            pitch <= 127 &&
            (allowed?.contains(pitch % 12) ?? false)) {
          choices.add(pitch);
        }
      }
      if (choices.length > 1) lastChoice = n.tick;
    }
    candidates.add(choices);
  }
  // Find a complete melodic path, rather than choosing each note in isolation.
  // Score proximity to the motif, preservation of contour, and smooth arrival
  // into the next written note (including the unaltered cadence).
  var costs = <double>[0];
  final parents = <List<int>>[
    [-1]
  ];
  for (var index = 1; index < candidates.length; index++) {
    final original = notes[from + index].pitch;
    final originalStep = original - notes[from + index - 1].pitch;
    final nextCosts = <double>[];
    final back = <int>[];
    for (final pitch in candidates[index]) {
      var best = double.infinity;
      var parent = 0;
      for (var j = 0; j < costs.length; j++) {
        final step = pitch - candidates[index - 1][j];
        final target = original + direction * 2;
        final local = candidates[index].length == 1
            ? 0.0
            : (pitch - target).abs() * .8 + (pitch == original ? 1.5 : 0);
        final score = costs[j] +
            local +
            (step - originalStep).abs() * .35 +
            (step.abs() > 5 ? (step.abs() - 5) * 2 : 0);
        if (score < best) {
          best = score;
          parent = j;
        }
      }
      nextCosts.add(best);
      back.add(parent);
    }
    parents.add(back);
    costs = nextCosts;
  }
  var selected = 0;
  for (var i = 1; i < costs.length; i++) {
    if (costs[i] < costs[selected]) selected = i;
  }
  for (var index = candidates.length - 1; index >= 0; index--) {
    result[from + index] = candidates[index][selected];
    selected = parents[index][selected];
  }
}

/// Additional notes share their source melody note's instrument and dynamics.
typedef JazzMelodyFill = ({int sourceIndex, int tick, int end, int pitch});

/// Sparse, unhurried answers in sustained notes or roomy gaps. Keep at least
/// one full beat of the original note, allow at most two added notes per four bars,
/// and choose the entire answer against its next melodic destination. There is
/// no bar-end deadline; each added note gets at least a beat and 400 ms.
List<JazzMelodyFill> jazzMelodyFills(
  List<JazzPhraseNote> notes, {
  required int division,
  required int beatsPerBar,
  required double bpm,
  required Map<int, JazzHarmony> harmony,
}) {
  final result = <JazzMelodyFill>[];
  final step = (division * bpm * .4 / 60).ceil().clamp(division, division * 4);
  final bar = division * beatsPerBar;
  var nextAllowed = notes.isEmpty ? 0 : notes.first.tick + bar;
  for (var i = 0; i + 1 < notes.length; i++) {
    final note = notes[i];
    final next = notes[i + 1];
    if (note.tick < nextAllowed ||
        note.end > next.tick ||
        (i > 0 && notes[i - 1].end > note.tick)) {
      continue;
    }
    final earliest = note.tick + step;
    // Leave a breath if using a rest; never overlap the next written attack.
    final limit =
        next.tick - (next.tick - note.end >= division ? division ~/ 2 : 0);
    final start = limit - 2 * step > earliest ? limit - 2 * step : earliest;
    final count = ((limit - start) ~/ step).clamp(0, 2);
    if (count == 0) continue;
    final choices = <List<int>>[];
    for (var slot = 0; slot < count; slot++) {
      final tick = start + slot * step;
      final end = tick + step;
      final pitches = <int>[];
      for (var pitch = note.pitch - 5; pitch <= note.pitch + 5; pitch++) {
        if (pitch < 0 || pitch > 127) continue;
        var fits = true;
        for (var beat = tick ~/ division;
            beat <= (end - 1) ~/ division;
            beat++) {
          final chord = harmony[beat];
          if (chord == null ||
              !(_tones[chord.quality]?.contains((pitch - chord.rootPc) % 12) ??
                  false)) {
            fits = false;
            break;
          }
        }
        if (fits) pitches.add(pitch);
      }
      choices.add(pitches);
    }
    List<int>? best;
    var bestCost = double.infinity;
    void search(List<int> path) {
      final previous = path.isEmpty ? note.pitch : path.last;
      if (path.length == count) {
        if ((previous - next.pitch).abs() > 5) return;
        var cost = (previous - next.pitch).abs().toDouble();
        var prior = note.pitch;
        for (var j = 0; j < path.length; j++) {
          final target =
              note.pitch + (next.pitch - note.pitch) * (j + 1) / (count + 1);
          cost += (path[j] - prior).abs() + (path[j] - target).abs();
          prior = path[j];
        }
        if (cost < bestCost) {
          bestCost = cost;
          best = [...path];
        }
        return;
      }
      for (final pitch in choices[path.length]) {
        if (pitch != previous && (pitch - previous).abs() <= 5) {
          search([...path, pitch]);
        }
      }
    }

    search([]);
    if (best == null) continue;
    for (var j = 0; j < best!.length; j++) {
      result.add((
        sourceIndex: i,
        tick: start + j * step,
        end: start + (j + 1) * step,
        pitch: best![j]
      ));
    }
    nextAllowed = result.last.end + 4 * bar;
  }
  return result;
}
