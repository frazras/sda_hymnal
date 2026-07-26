import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HymnPage extends StatefulWidget {
  final Hymn hymn;
  final List<Hymn> hymns;
  const HymnPage({super.key, required this.hymn, required this.hymns});

  @override
  State<HymnPage> createState() => _HymnPageState();
}

class _HymnPageState extends State<HymnPage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Future<double>? fontSizeValue;

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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: FittedBox(
            fit: BoxFit.fitWidth,
            child: Text("${widget.hymn.number} ${widget.hymn.title}")),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        height: double.infinity,
        child: SingleChildScrollView(
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              const sensitivity = 1;
              if (details.delta.dx > sensitivity &&
                  ((widget.hymn.number - 2) > -1)) {
                // Right Swipe: go to the previous hymn
                Navigator.pushReplacement(context, swipe('right'));
              } else if (details.delta.dx < -sensitivity &&
                  ((widget.hymn.number < 695 && widget.hymn.version == "new") ||
                      (widget.hymn.number < 703 &&
                          widget.hymn.version == "old"))) {
                // Left Swipe: go to the next hymn
                Navigator.pushReplacement(context, swipe('left'));
              }
            },
            child: FutureBuilder(
                future: fontSizeValue,
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    double size = snapshot.data ?? 18.0;
                    return Container(
                      height: 1000,
                      child: Html(data: widget.hymn.body, style: {
                        "html": Style(
                            color: Colors.black, fontSize: FontSize(size))
                      }),
                    );
                  }
                }),
          ),
        ),
      ),
    );
  }

  PageRouteBuilder swipe(direction) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => HymnPage(
        hymn: widget.hymns[widget.hymn.number - (direction == "left" ? 0 : 2)],
        hymns: widget.hymns,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(direction == "left" ? 1.0 : -1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}
