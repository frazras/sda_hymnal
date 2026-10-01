import 'dart:async';
import '../services/playback_continuation.dart';

import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:sdahymnal/models/hymn_video.dart';
import 'package:sdahymnal/theme.dart';

/// A compact in-app player that floats above the still-scrollable lyrics.
class HymnVideoOverlay extends StatefulWidget {
  final HymnVideo video;
  final VoidCallback onClose;
  final VoidCallback? onEnded;

  const HymnVideoOverlay({
    super.key,
    required this.video,
    required this.onClose,
    this.onEnded,
  });

  @override
  State<HymnVideoOverlay> createState() => _HymnVideoOverlayState();
}

class _HymnVideoOverlayState extends State<HymnVideoOverlay> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  bool _reportedError = false;
  final _endGate = PlaybackEndGate();

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.youtubeVideoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        privacyEnhancedMode: true,
        strictRelatedVideos: true,
      ),
    );
    _subscription = _controller.listen((value) {
      if (!mounted) return;
      if (value.hasError) {
        _endGate.stop();
      } else if (value.playerState == PlayerState.playing) {
        _endGate.playing();
      } else if (value.playerState == PlayerState.paused) {
        _endGate.stop();
      } else if (value.playerState == PlayerState.ended && _endGate.ended()) {
        widget.onEnded?.call();
      }
      if (value.hasError && !_reportedError) {
        _reportedError = true;
        AppAnalytics.instance.event('video_error');
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      key: const ValueKey('hymn-youtube-player'),
      color: t.surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.smart_display_outlined, color: t.accent, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kSans,
                          color: t.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.video.channel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kSans,
                          color: t.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-hymn-youtube-player'),
                  tooltip: 'Close video',
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: t.muted, size: 19),
                ),
              ],
            ),
          ),
          // YouTube requires embedded players to be at least 200x200. The
          // dynamic aspect ratio keeps this mini-player exactly 200px tall.
          LayoutBuilder(
            builder: (context, constraints) => YoutubePlayer(
              controller: _controller,
              aspectRatio: constraints.maxWidth / 200,
              backgroundColor: Colors.black,
              autoFullScreen: false,
            ),
          ),
        ],
      ),
    );
  }
}
