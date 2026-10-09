/// Calls and route changes pause playback; ending an interruption never resumes it.
class AudioInterruptionPolicy {
  AudioInterruptionPolicy({required this.cancelPending, required this.pause});

  final void Function() cancelPending;
  final Future<void> Function() pause;

  Future<void> interruption({required bool begin}) async {
    if (begin) await _pause();
  }

  Future<void> headphonesRemoved() => _pause();

  Future<void> _pause() async {
    // Invalidate a prepared next song synchronously, before engine work is queued.
    cancelPending();
    try {
      await pause();
    } catch (_) {
      // Platform event streams must survive an engine error so later events retry.
    }
  }
}
