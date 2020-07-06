import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';

class Buttons extends StatefulWidget {
  @override
  _ButtonsState createState() => new _ButtonsState();
}

class _ButtonsState extends State<Buttons> {
  String displayNumber = "";
  String oldTitle ="";
  String newTitle = "";
  List<Hymn> _hymns_new = [];
  List<Hymn> _hymns_old = [];

  @override
  void initState() {
    super.initState();
    _loadHymns();
    print("hymnsloaded");
    _buildButtons();
  }

  _loadHymns() async {
    String fileData = await DefaultAssetBundle.of(context).loadString("assets/hymns.json");
    setState(() {
      _hymns_new = HymnApi.allHymnsFromJson(fileData, 'new');
      _hymns_old = HymnApi.allHymnsFromJson(fileData, 'old');
    });
  }
  writeToScreen(text){
    int num;
    String inp = "";
    try {
      inp = text.data;
    }
    catch (e){}
    try {
        num = int.parse(text.data);
    }
    catch (e){}
    try {
      num = text.icon.codePoint;
    }
    catch (e) {}

    if (inp == "NEW»") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HymnPage(
              hymn: _hymns_new[int.parse(displayNumber) - 1]
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
              hymn: _hymns_old[int.parse(displayNumber) - 1]
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
      });
      return;
    }
    print(num);
    if (num == 57674 && displayNumber.length > 0){
      setState(() {
        displayNumber = displayNumber.substring(0, displayNumber.length - 1);
        if (displayNumber != "") {
          newTitle = _hymns_new[int.parse(displayNumber) - 1].title;
          oldTitle = _hymns_old[int.parse(displayNumber) - 1].title;
        } else {
          newTitle = "";
          oldTitle = "";
        }
      });
      return;
    }
    int number = int.tryParse(displayNumber) ?? 0;

    setState(() {
      if (displayNumber.length < 3 && int.parse(displayNumber + inp) < 704){
        displayNumber += inp;
        newTitle = _hymns_new[int.parse(displayNumber == "" ? num : displayNumber) - 1].title;
        oldTitle = _hymns_old[int.parse(displayNumber == "" ? num : displayNumber) - 1].title;
      }

    });

  }
  Widget _buttonIcon(icon){
    return _button(Icon(
      icon,
      size: 48,
    ));
  }
  Widget _buttonText(text){
    return _button(Text(
      text,
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold
      ),
    ));
  }

  Widget _button(data) {
    return Expanded(
      child:  Container(
        margin: const EdgeInsets.all(5.0),
        child :OutlineButton (
            child: data,
            onPressed: () => writeToScreen(data),
            color: Colors.red,
            textColor: Colors.black,
            padding: EdgeInsets.all(10.0),
            borderSide: BorderSide(width: 2.0, color: Colors.black),
        )
      )
    );
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
              child: Text(
                displayNumber,
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 40,
                    fontWeight: FontWeight.bold
                ),
              ),
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
                    padding: EdgeInsets.all(10.0),
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
                  padding: EdgeInsets.all(10.0),
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
    return new Scaffold(
      body: _buildButtons(),
    );
  }
}