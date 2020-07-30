import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Buttons extends StatefulWidget {
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;
  
  Buttons({Key key,@required this.hymnsOld, @required this.hymnsNew}) : super(key:key);
  
  @override
  _ButtonsState createState() => new _ButtonsState();
}

class _ButtonsState extends State<Buttons> {
  String displayNumber = "";
  bool disabled;
  String oldTitle ="";
  String newTitle = "";
  var disabledButtons = ["OLD»", "NEW»"];
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Future<double> fontSizeValue;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
    _buildButtons();
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

  writeToScreen(buttonData){
    int num;
    String inp = "";
    try {
      inp = buttonData.data;
    }
    catch (e){}
    try {
        num = int.parse(buttonData.data);
    }
    catch (e){}
    try {
      num = buttonData.icon.codePoint;
    }
    catch (e) {}

    if (inp == "NEW»") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HymnPage(
              hymn: widget.hymnsNew[int.parse(displayNumber) - 1],
              hymns: widget.hymnsNew,
          ),
        ),
      );
      return;
    }
    if (inp == "OLD»") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HymnPage(
              hymn: widget.hymnsOld[int.parse(displayNumber) - 1],
              hymns: widget.hymnsOld,
          ),
        ),
      );
      return;
    }
    if (num == 58825){
      setState(() {
        displayNumber = "";
        newTitle = "";
        oldTitle = "";
        disabledButtons.addAll(["OLD»", "NEW»"]);
      });
      return;
    }
    print(num);
    if (num == 57674){
      if (displayNumber.length < 1) return;
      setState(() {
        displayNumber = displayNumber.substring(0, displayNumber.length - 1);
        if (displayNumber != "") {
          newTitle = widget.hymnsNew[int.parse(displayNumber) - 1].title;
          oldTitle = widget.hymnsOld[int.parse(displayNumber) - 1].title;
          disabledButtons.remove("NEW»");
        } else {
          newTitle = "";
          oldTitle = "";
          disabledButtons.addAll(["OLD»", "NEW»"]);
        }
      });
      return;
    }
    int number = int.tryParse(displayNumber) ?? 0;

    setState(() {
      int requestedNum = int.parse(displayNumber + inp);
      const old_max = 703;
      const new_max = 695;
      if (displayNumber.length < 3 && requestedNum <= old_max){
        displayNumber += inp;

        if (requestedNum > new_max) {
          newTitle = "...";
          disabledButtons.add("NEW»");

        }
        else {
          newTitle = widget.hymnsNew[int.parse(displayNumber == "" ? num : displayNumber) - 1].title;
          disabledButtons.remove("NEW»");
        }

        oldTitle = widget.hymnsOld[int.parse(displayNumber == "" ? num : displayNumber) - 1].title;
        disabledButtons.remove("OLD»");
      }

    });

  }
  Widget _buttonIcon(icon) {
    return FutureBuilder(
        future: fontSizeValue,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            double size = snapshot.data;
            return _button(Icon(
              icon,
              size: (size ?? 18.0) + 4.0,
            ));
          }
        });
  }
  Widget _buttonText(text){
    return FutureBuilder(
        future: fontSizeValue,
        builder: (BuildContext context, AsyncSnapshot snapshot){
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            double size = snapshot.data;
            return _button(Text(
              text,
              style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.bold
              ),
            ));
          }
        });
  }

  Widget _button(data) {
    return Expanded(
      child:  Container(
        margin: const EdgeInsets.all(5.0),
        child :OutlineButton (
            child: data,
            onPressed: isDisabled(data) ? null : () => writeToScreen(data),
            color: Colors.red,
            disabledBorderColor: Colors.grey[300],
            disabledTextColor: Colors.grey[300],

            textColor: Colors.black,
            padding: EdgeInsets.all(10.0),
            borderSide: BorderSide(width: 2.0, color: Colors.black),
        )
      )
    );
  }

  bool isDisabled(buttonData) {
    int num;
    String inp = "";
    try {
      inp = buttonData.data;
    }
    catch (e){}
    try {
      num = int.parse(buttonData.data);
    }
    catch (e){}
    try {
      num = buttonData.icon.codePoint;
    }
    catch (e) {}

    return disabledButtons.indexWhere((item) => item == inp) >= 0;
  }

  Widget _buildButtons() {
    return new Container(
      margin: const EdgeInsets.fromLTRB(
          8.0, // A left margin of 8.0
          6.0, // A top margin of 56.0
          8.0, // A right margin of 8.0
          0.0 // A bottom margin of 0.0
      ),
      child: SingleChildScrollView(
        child: new Column(
          // A column widget can have several
          // widgets that are placed in a top down fashion
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(10.0),
              child: FutureBuilder(
              future: fontSizeValue,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  double size = snapshot.data;
                  return Text(
                    displayNumber,
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: size,
                        fontWeight: FontWeight.bold
                    ),
                  );
                }
              }),
            ),
            Row(
              children: <Widget>[
                _buttonText("1"),
                _buttonText("2"),
                _buttonText("3")],
            ),
            Row(
              children: <Widget>[
                _buttonText("4"),
                _buttonText("5"),
                _buttonText("6")],
            ),
            Row(
              children: <Widget>[
                _buttonText("7"),
                _buttonText("8"),
                _buttonText("9")],
            ),
            Row(
              children: <Widget>[
                _buttonIcon(Icons.cancel),
                _buttonText("0"),
                _buttonIcon(Icons.backspace)],
            ),
            Row(
              children: <Widget>[
                _buttonText("OLD»"),
                _buttonText("NEW»")],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(2.0),
                    child: Text(
                      "NEW: " + displayNumber + " " + newTitle,
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(2.0),
                  child: Text(
                    "OLD: " + displayNumber + " " + oldTitle,
                    //"OLD: " + displayNumber + " " + oldTitle,
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            )

          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).unfocus(); //disable keyboard.
    return new Scaffold(
      body: _buildButtons(),
    );
  }
}