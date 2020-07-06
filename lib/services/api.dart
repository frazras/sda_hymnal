import 'dart:convert';
import 'package:sdahymnal/models/hymn.dart';

class HymnApi {
  static List<Hymn> allHymnsFromJson(String jsonData,[String version]) {
    List<Hymn> hymns = [];
    json.decode(jsonData)['hymns'].forEach((hymn) => hymns.add(_fromMap(hymn)));
    hymns.sort((a, b) {
      int cmp = a.number.compareTo(b.number);
      if (cmp != 0) return cmp;
      return a.version.compareTo(b.version);
    });
    if (version != null) {
      hymns = hymns.where((f) => f.version.contains(version)).toList();
    }
    return hymns;
  }

  static Hymn _fromMap(Map<String, dynamic> map) {
    return new Hymn(
        number: map['number'],
        title: map['title'],
        body: map['body'],
        version: map['version']
    );
  }
}
