import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:sdahymnal/models/hymn.dart';

class HymnPage extends StatelessWidget{
  final Hymn hymn;

  HymnPage({Key key, @required this.hymn}) : super(key:key);

  @override
  Widget build(BuildContext context) {
    // Use the Todo to create the UI.
    return Scaffold(
      appBar: AppBar(
        title: Text(hymn.number.toString() + " " + hymn.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Html(data: hymn.body,
            style: {"html" : Style(color: Colors.black, fontSize: FontSize.xxLarge)}),
        ),
      ),
    );
  }
}