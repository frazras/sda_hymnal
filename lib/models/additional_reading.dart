class AdditionalReading {
  final String id;
  final String edition;
  final int order;
  final int number;
  final String title;
  final String category;
  final String? scriptureReference;
  final List<ReadingSegment> segments;

  const AdditionalReading({
    required this.id,
    required this.edition,
    required this.order,
    required this.number,
    required this.title,
    required this.category,
    this.scriptureReference,
    required this.segments,
  });

  factory AdditionalReading.fromJson(Map<String, dynamic> json) {
    return AdditionalReading(
      id: json['id'] as String,
      edition: json['edition'] as String? ?? 'new',
      order: json['order'] as int? ?? 0,
      number: json['number'] as int,
      title: json['title'] as String,
      category: json['category'] as String? ?? 'Additional Reading',
      scriptureReference: (json['scriptureReference'] as String?)?.trim(),
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .map((item) => ReadingSegment.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ReadingSegment {
  final String role;
  final String text;

  const ReadingSegment({required this.role, required this.text});

  factory ReadingSegment.fromJson(Map<String, dynamic> json) => ReadingSegment(
        role: json['role'] as String? ?? 'leader',
        text: json['text'] as String? ?? '',
      );

  bool get isCongregation => role.toLowerCase() == 'congregation';
}

class AdditionalReadingCatalog {
  final List<AdditionalReading> readings;

  const AdditionalReadingCatalog(this.readings);

  factory AdditionalReadingCatalog.fromJson(Map<String, dynamic> json) {
    final readings = (json['readings'] as List<dynamic>? ?? const [])
        .map((item) => AdditionalReading.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return AdditionalReadingCatalog(readings);
  }

  List<String> get categories => readings
      .map((reading) => reading.category)
      .toSet()
      .toList(growable: false);
}
