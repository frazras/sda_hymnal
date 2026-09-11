import 'dart:convert';

const appReleaseVersion = '4.3.0';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.date,
    required this.features,
  });

  final String version;
  final String date;
  final List<String> features;

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        version: json['version'] as String,
        date: json['date'] as String,
        features: List<String>.unmodifiable(
          (json['features'] as List).cast<String>(),
        ),
      );
}

class ReleaseNotesCatalog {
  const ReleaseNotesCatalog({
    required this.currentVersion,
    required this.releases,
  });

  final String currentVersion;
  final List<AppRelease> releases;

  AppRelease get current =>
      releases.firstWhere((release) => release.version == currentVersion);

  factory ReleaseNotesCatalog.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final releases = List<AppRelease>.unmodifiable(
      (json['releases'] as List)
          .cast<Map<String, dynamic>>()
          .map(AppRelease.fromJson),
    );
    final current = json['current'] as String;
    if (releases.isEmpty || !releases.any((item) => item.version == current)) {
      throw const FormatException('Current release is missing from history');
    }
    return ReleaseNotesCatalog(currentVersion: current, releases: releases);
  }
}
