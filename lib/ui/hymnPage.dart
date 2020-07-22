import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:sdahymnal/models/hymn.dart';

class HymnPage extends StatelessWidget{
  final Hymn hymn;
  final List<Hymn> hymns;

  HymnPage({Key key, @required this.hymn, this.hymns}) : super(key:key);

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
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              const sensitivity = 1;
              if (details.delta.dx > sensitivity && ((hymn.number - 2) > -1)) {
                print("swipe right");
                print(hymn.number);
                print(details.delta.dx);
                // Right Swipe
                // Sensitivity is integer is used when you don't want to mess up vertical drag
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HymnPage(
                        hymn: hymns[hymn.number - 2],
                        hymns: hymns,
                    ),
                  ),
                );
              } else if(details.delta.dx < -sensitivity &&
                  ((hymn.number < 695 && hymn.version == "new")
                      || (hymn.number < 703 && hymn.version == "old"))){
                print("swipe lefty");
                print(hymn.number);

                print(hymn.version);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HymnPage(
                      hymn: hymns[hymn.number],
                      hymns: hymns,
                    ),
                  ),
                );
                //Left Swipe
              }
            },
            child: Html(data: hymn.body,
              style: {"html" : Style(color: Colors.black, fontSize: FontSize.xxLarge)}),
          ),
        ),
      ),
    );
  }
}