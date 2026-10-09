import 'package:flutter/widgets.dart';
import '../models/playback_queue.dart';

enum HymnContinuation { midi, video }

/// An explicit occurrence sequence shared by hymn and reading screens.
/// Returning null at an automatic boundary stops playback without skipping it.
class ReaderSequence {
  final HymnPlaybackQueue? audioQueue;
  final int? audioIndex;
  final Widget? Function(int index, {bool showSheetMusic})? audioPage;
  final String label;
  final String Function(BuildContext context)? localizedLabel;

  String labelFor(BuildContext context) =>
      localizedLabel?.call(context) ?? label;
  final bool Function(int direction) canMove;
  final Widget? Function(int direction,
      {bool previewOnly,
      HymnContinuation? continuation,
      bool showSheetMusic}) page;

  const ReaderSequence(
      {required this.label,
      this.audioQueue,
      this.audioIndex,
      this.audioPage,
      this.localizedLabel,
      required this.canMove,
      required this.page});
}
