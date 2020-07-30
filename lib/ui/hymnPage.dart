import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HymnPage extends StatefulWidget {
  final Hymn hymn;
  final List<Hymn> hymns;
  HymnPage({Key key, @required this.hymn, this.hymns}) : super(key:key);

  @override
  _HymnPageState createState() => new _HymnPageState();
}

class _HymnPageState extends State<HymnPage> {

  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Future<double> fontSizeValue;

  _loadFontSize() async {
    final prefs = await _prefs;
    final double fs = prefs.getDouble('fontSize') ?? 18.0;
    setState(() {
      fontSizeValue = prefs.setDouble("fontSize", fs).then((bool success) {
        return fs;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  @override
  Widget build(BuildContext context) {
    // Use the Todo to create the UI.
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: FittedBox(fit:BoxFit.fitWidth,
            child: Text(widget.hymn.number.toString() + " " + widget.hymn.title)
        ),
        //title: Text(hymn.number.toString() + " " + hymn.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              const sensitivity = 1;
              if (details.delta.dx > sensitivity && ((widget.hymn.number - 2) > -1)) {
                print("swipe right");
                //print(hymn.number);
                print(details.delta.dx);
                // Right Swipe
                // Sensitivity is integer is used when you don't want to mess up vertical drag
                Navigator.pushReplacement(
                  context,
                    swipe('right')
                );
              } else if(details.delta.dx < -sensitivity &&
                  ((widget.hymn.number < 695 && widget.hymn.version == "new")
                      || (widget.hymn.number < 703 && widget.hymn.version == "old"))){
                print("swipe lefty");
                print(widget.hymn.number);

                print(widget.hymn.version);
                Navigator.pushReplacement(
                  context,
                  swipe('left')
                );
                //Left Swipe
              }
            },
            child:FutureBuilder(
              future: fontSizeValue,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  double size = snapshot.data;
                  return Html(data: widget.hymn.body,
                      style: {
                        "html": Style(
                            color: Colors.black, fontSize: FontSize(size))
                      });
                }
              }
            ),
          ),
        ),
      ),
    );
  }

  PageRouteBuilder swipe(direction){
    double move = direction == "left" ? 1.0 : -1.0;
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => HymnPage(
        hymn: widget.hymns[widget.hymn.number - (direction == "left" ? 0 : 2)],
        hymns: widget.hymns,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(direction == "left" ? 1.0 : -1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}