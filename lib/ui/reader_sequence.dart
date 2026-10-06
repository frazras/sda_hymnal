import 'package:flutter/widgets.dart';

enum HymnContinuation { midi, video }

/// An explicit occurrence sequence shared by hymn and reading screens.
/// Returning null at an automatic boundary stops playback without skipping it.
class ReaderSequence {
  final String label;
  final bool Function(int direction) canMove;
  final Widget? Function(int direction,
      {bool previewOnly,
      HymnContinuation? continuation,
      bool showSheetMusic}) page;

  const ReaderSequence(
      {required this.label, required this.canMove, required this.page});
}
