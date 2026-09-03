import 'dart:convert';

class HymnMetadataCatalog {
  final Map<String, HymnMetadata> _byReference;

  const HymnMetadataCatalog._(this._byReference);

  factory HymnMetadataCatalog.fromJson(String jsonData) {
    final data = json.decode(jsonData) as Map<String, dynamic>;
    final sourceNames = <String, String>{};
    for (final source in data['sources'] as List<dynamic>? ?? const []) {
      final map = source as Map<String, dynamic>;
      sourceNames[map['id'] as String] = map['name'] as String;
    }

    final records = <String, HymnMetadata>{};
    for (final raw in data['hymns'] as List<dynamic>? ?? const []) {
      final metadata = HymnMetadata.fromMap(
        raw as Map<String, dynamic>,
        sourceNames,
      );
      records[metadata.id] = metadata;
    }

    final byReference = <String, HymnMetadata>{};
    final lookup = data['lookup'] as Map<String, dynamic>? ?? const {};
    for (final entry in lookup.entries) {
      final metadata = records[entry.value as String];
      if (metadata != null) byReference[entry.key] = metadata;
    }
    return HymnMetadataCatalog._(byReference);
  }

  HymnMetadata? forHymn(String version, int number) =>
      _byReference['$version:$number'];
}

class HymnMetadata {
  final String id;
  final String title;
  final List<String> authors;
  final List<String> composers;
  final Map<String, List<HymnEditionMetadata>> editions;
  final List<HymnStory> stories;

  const HymnMetadata({
    required this.id,
    required this.title,
    required this.authors,
    required this.composers,
    required this.editions,
    required this.stories,
  });

  factory HymnMetadata.fromMap(
    Map<String, dynamic> map,
    Map<String, String> sourceNames,
  ) {
    final editions = <String, List<HymnEditionMetadata>>{};
    for (final entry
        in (map['editions'] as Map<String, dynamic>? ?? const {}).entries) {
      editions[entry.key] = (entry.value as List<dynamic>)
          .map((item) => HymnEditionMetadata.fromMap(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false);
    }
    return HymnMetadata(
      id: map['id'] as String,
      title: map['title'] as String,
      authors: _strings(map['authors']),
      composers: _strings(map['composers']),
      editions: editions,
      stories: (map['stories'] as List<dynamic>? ?? const [])
          .map((item) => HymnStory.fromMap(
                item as Map<String, dynamic>,
                sourceNames,
              ))
          .toList(growable: false),
    );
  }

  HymnEditionMetadata? editionFor(String version, int number) {
    for (final edition in editions[version] ?? const []) {
      if (edition.number == number) return edition;
    }
    return null;
  }

  List<String> authorsFor(String version, int number) {
    final editionAuthors = editionFor(version, number)?.authors ?? const [];
    return editionAuthors.isNotEmpty ? editionAuthors : authors;
  }

  List<String> composersFor(String version, int number) {
    final editionComposers = editionFor(version, number)?.composers ?? const [];
    return editionComposers.isNotEmpty ? editionComposers : composers;
  }
}

class HymnEditionMetadata {
  final int number;
  final List<String> authors;
  final List<String> composers;
  final String? firstLine;
  final String? refrainFirstLine;
  final String? meter;
  final String? tuneTitle;
  final String? key;
  final String? topic;
  final String? year;

  const HymnEditionMetadata({
    required this.number,
    required this.authors,
    required this.composers,
    this.firstLine,
    this.refrainFirstLine,
    this.meter,
    this.tuneTitle,
    this.key,
    this.topic,
    this.year,
  });

  factory HymnEditionMetadata.fromMap(Map<String, dynamic> map) =>
      HymnEditionMetadata(
        number: map['number'] as int,
        authors: _strings(map['authors']),
        composers: _strings(map['composers']),
        firstLine: map['firstLine'] as String?,
        refrainFirstLine: map['refrainFirstLine'] as String?,
        meter: map['meter'] as String?,
        tuneTitle: map['tuneTitle'] as String?,
        key: map['key'] as String?,
        topic: map['topic'] as String?,
        year: map['year'] as String?,
      );
}

class HymnStory {
  final String id;
  final String title;
  final String? text;
  final String sourceId;
  final String sourceName;
  final Uri? sourceUrl;
  final String? rawAttribution;

  const HymnStory({
    required this.id,
    required this.title,
    required this.text,
    required this.sourceId,
    required this.sourceName,
    required this.sourceUrl,
    required this.rawAttribution,
  });

  factory HymnStory.fromMap(
    Map<String, dynamic> map,
    Map<String, String> sourceNames,
  ) {
    final sourceId = map['sourceId'] as String;
    final sourceUrl = map['sourceUrl'] as String?;
    return HymnStory(
      id: map['id'] as String,
      title: map['title'] as String,
      text: map['text'] as String?,
      sourceId: sourceId,
      sourceName: sourceNames[sourceId] ?? sourceId,
      sourceUrl: sourceUrl == null ? null : Uri.tryParse(sourceUrl),
      rawAttribution: map['rawAttribution'] as String?,
    );
  }

  bool get hasText => text?.trim().isNotEmpty ?? false;
}

List<String> _strings(dynamic value) =>
    (value as List<dynamic>? ?? const []).cast<String>();
