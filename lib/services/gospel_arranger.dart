import 'dart:typed_data';

import 'package:sdahymnal/services/style_arranger.dart';

/// Gospel accompaniment for the bundled hymn tunes — kept as a thin wrapper
/// over the shared style engine so existing callers and tests keep working.
///
/// The engine itself (SMF parse, chord recovery, per-bar comp/bass/drum
/// generation, SMF writing) lives in style_arranger.dart, where 'gospel' is
/// one of several [ArrangeStyle]s alongside 'reggae' and 'calypso'.

/// Rewrites the hymn SMF in [originalBytes] as a modern-gospel arrangement:
/// melody preserved on Rhodes, rootless Rhodes comp stabs, finger bass with
/// chromatic walk-ins, and a subtle hat/kick/sidestick groove — driven by
/// the harmony detected in the original file.
///
/// Throws [FormatException] when [originalBytes] is not a well-formed SMF or
/// contains no detectable harmony (the caller falls back to the original).
Uint8List arrangeGospel(Uint8List originalBytes) =>
    arrangeStyle(originalBytes, ArrangeStyle.gospel);
