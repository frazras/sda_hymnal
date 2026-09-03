import 'dart:convert';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/models/hymn_video.dart';

class HymnApi {
  static List<Hymn> allHymnsFromJson(
    String jsonData, {
    HymnMetadataCatalog? metadata,
    HymnVideoCatalog? videos,
  }) {
    List<Hymn> hymns = [];
    json
        .decode(jsonData)['hymns']
        .forEach((hymn) => hymns.add(_fromMap(hymn, metadata, videos)));
    hymns.sort((a, b) {
      int cmp = a.number.compareTo(b.number);
      if (cmp != 0) return cmp;
      return a.version.compareTo(b.version);
    });
    return hymns;
  }

  static Hymn _fromMap(
    Map<String, dynamic> map,
    HymnMetadataCatalog? metadata,
    HymnVideoCatalog? videos,
  ) {
    return Hymn(
        number: map['number'],
        title: map['title'],
        body: map['body'],
        version: map['version'],
        metadata: metadata?.forHymn(map['version'], map['number']),
        video: videos?.forHymn(map['version'], map['number']));
  }
}
