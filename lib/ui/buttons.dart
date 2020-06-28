import 'package:flutter/material.dart';

class Buttons extends StatefulWidget {
  @override
  _ButtonsState createState() => new _ButtonsState();
}

class _ButtonsState extends State<Buttons> {
  String displayNumber = "";
  writeToScreen(text){
    int num;
    String inp = "";
    try {
        num = int.parse(text.data);
        inp = text.data;
        }
    catch (e){}
    try { num = text.icon.codePoint;}
    catch (e) {}

    if (num == 58825){
      setState(() {
        displayNumber = "";
      });
      return;
    }
    print(num);
    if (num == 57674 && displayNumber.length > 0){
      setState(() {
        displayNumber = displayNumber.substring(0, displayNumber.length - 1);
      });
      return;
    }
    int number = int.tryParse(displayNumber) ?? 0;

    setState(() {
      if (displayNumber.length < 3 && int.parse(displayNumber + inp) < 704){
        displayNumber += inp;
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
              _buttonText("99")],
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

        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _buildButtons();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: _buildButtons(),
    );
  }
}