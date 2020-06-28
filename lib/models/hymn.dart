import 'package:meta/meta.dart';

class Hymn {
  final int number;
  final String title;
  final String body;
  final String version;

  Hymn({
    @required this.number,
    @required this.title,
    @required this.body,
    @required this.version,
  });

  @override
  String toString() {
    return "Hymn #$number $title $version";
  }
}
