import 'dart:convert';

/// A curated YouTube recording that can be embedded beside a hymn's lyrics.
class HymnVideo {
  final String youtubeVideoId;
  final String title;
  final String channel;
  final String channelId;
  final int priority;

  const HymnVideo({
    required this.youtubeVideoId,
    required this.title,
    required this.channel,
    required this.channelId,
    required this.priority,
  });

  factory HymnVideo.fromMap(Map<String, dynamic> map) => HymnVideo(
        youtubeVideoId: map['youtubeVideoId'] as String,
        title: map['title'] as String,
        channel: map['channel'] as String,
        channelId: map['channelId'] as String? ?? '',
        priority: map['priority'] as int,
      );
}

class HymnVideoCatalog {
  final Map<String, HymnVideo> _byReference;

  const HymnVideoCatalog._(this._byReference);

  factory HymnVideoCatalog.fromJson(String jsonData) {
    final data = json.decode(jsonData) as Map<String, dynamic>;
    final videos = <String, HymnVideo>{};
    for (final raw in data['videos'] as List<dynamic>? ?? const []) {
      final video = HymnVideo.fromMap(raw as Map<String, dynamic>);
      videos[video.youtubeVideoId] = video;
    }
    final byReference = <String, HymnVideo>{};
    final lookup = data['lookup'] as Map<String, dynamic>? ?? const {};
    for (final entry in lookup.entries) {
      final video = videos[entry.value as String];
      if (video != null) byReference[entry.key] = video;
    }
    return HymnVideoCatalog._(byReference);
  }

  HymnVideo? forHymn(String version, int number) =>
      _byReference['$version:$number'];
}
