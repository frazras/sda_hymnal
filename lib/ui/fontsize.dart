import 'package:flutter/material.dart';
import 'package:flutter_html/style.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';


class FontSizer extends StatefulWidget {
  @override
  _FontSizerState createState() => new _FontSizerState();
}

class _FontSizerState extends State<FontSizer> {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Future<double> fontSizeValue;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  _loadFontSize() async {
    final prefs = await _prefs;
    final double fs = prefs.getDouble('fontSize') ?? 18.0;
    setState(() {
      fontSizeValue = prefs.setDouble("fontSize", fs).then((bool success) {
        return fs;
      });
    });
  }
  _saveFontSize(double newFontSize) async {
    final prefs = await _prefs;
    setState(() {
      fontSizeValue =
      prefs.setDouble("fontSize", newFontSize).then((bool success) {
        return newFontSize;
      });
    });
  }

  Widget _buildFontSizer() {
    return FutureBuilder(
      future: fontSizeValue,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              double x = snapshot.data;
              return Column(
                  children: <Widget>[
                     Padding(
                       padding: const EdgeInsets.only(top:38.0),
                       child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.red[700],
                          inactiveTrackColor: Colors.red[100],
                          trackShape: RoundedRectSliderTrackShape(),
                          trackHeight: 4.0,
                          thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: 12.0),
                          thumbColor: Colors.redAccent,
                          overlayColor: Colors.red.withAlpha(32),
                          overlayShape: RoundSliderOverlayShape(
                              overlayRadius: 28.0),
                          tickMarkShape: RoundSliderTickMarkShape(),
                          activeTickMarkColor: Colors.red[700],
                          inactiveTickMarkColor: Colors.red[100],
                          valueIndicatorShape: PaddleSliderValueIndicatorShape(),
                          valueIndicatorColor: Colors.redAccent,
                          valueIndicatorTextStyle: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        child: Slider(
                          value: x,
                          min: 16,
                          max: 30,
                          divisions: 14,
                          label: '$x',
                          onChanged: (value) {
                            setState(() {
                              _saveFontSize(value);
                            });
                            },
                        ),
                       ),
                     ),
                      Html(
                        data: "<font color=\"#0B6138\"><b>1</b></font><br>\nAll creatures of our God and King,<br>\nLift up your voice with us and sing:<br>\nAlleluia! Alleluia!<br>\nO burning sun with golden beam<br>\nAnd silver moon with softer gleam:<br>\n<br>\n<i><b><font color=\"#CD9B1D\">CHORUS:</font></b><br>\nOh, praise Him! Oh, praise Him!<br>\nAlleluia, alleluia, alleluia!<br>\n</i><br>\n<font color=\"#0B6138\"><b>2</b></font><br>\nO rushing wind and breezes soft,<br>\nO clouds that ride the winds aloft:<br>\nOh, praise Him! Alleluia!<br>\nO rising morn, in praise rejoice,<br>\nO lights of evening, find a voice.<br>\n<br>\n",
                        style: {
                          "html": Style(color: Colors.black,
                          fontSize: FontSize(snapshot.data))
                          }
                          )
                  ]
              );
            }
        },
    );
  }

          @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
          title: Text("Font Size")
      ),
      body: Padding(
        padding: const EdgeInsets.only(left : 20.0, right: 20.0, top: 10.0),
        child: SingleChildScrollView(
            child: _buildFontSizer()
        ),
      ),
    );
  }
}

