import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';


class HymnList extends StatefulWidget {
  final List<Hymn> hymns;
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;

  HymnList({Key key, @required this.hymns, @required this.hymnsOld, @required this.hymnsNew}) : super(key:key);

  @override
  _HymnListState createState() => new _HymnListState();
}

class _HymnListState extends State<HymnList> {

  List<Hymn> _filteredHymns;
  String filter = "ALL";

  @override
  void initState() {
    super.initState();
    _filteredHymns = widget.hymns;
  }

  Widget _buildHymnItem(BuildContext context, int index) {
    Hymn hymn = _filteredHymns[index];

    return new Container(
      child: new Card(
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Container (
              decoration: new BoxDecoration (
                  color: hymn.version == 'new' ? Colors.white : Colors.grey[300],
                  border: Border.all(
                      color: Colors.black,
                      width: 2.0
                  ),
              ),
              padding: EdgeInsets.all(0.0),
              child: ListTile(

                        title:  new Text(
                          hymn.number.toString() + '. '  +hymn.title,
                          style: new TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Colors.black54,
                              fontSize: 16.0,
                          ),
                        ),
                        leading: SvgPicture.asset(
                          hymn.version == 'new' ? "assets/lettern.svg" : "assets/lettero.svg",
                          semanticsLabel: 'Letter N/O',
                          width: 32,
                        ),
                        //subtitle: new Text(hymn.version.toUpperCase() + " Hymnal"),
                        //isThreeLine: true, // Less Cramped Tile
                        contentPadding: EdgeInsets.symmetric(horizontal: 1.0, vertical: 0.0),
                        dense: true, // Less Cramped Tile
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HymnPage(hymn: _filteredHymns[index],
                                  hymns: _filteredHymns[index].version == 'new' ?
                                          widget.hymnsNew : widget.hymnsOld ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getAppTitleWidget() {
    return CupertinoTextField(
      style: TextStyle(color: Colors.white, fontSize: 20.0),
      placeholder: "Search Hymns",
      placeholderStyle: TextStyle(fontSize: 20.0, color: Color(0xff00FF00)),
      prefix: Container(
        padding: EdgeInsets.only(left: 10.0),
        child: Icon(
          Icons.search,
          color: Color(0xff00FF00),
          size: 40,
        ),
      ),
      padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
      onChanged: (query){
        var currentHymns = (filter == "OLD") ? widget.hymnsOld :
                          (filter == "NEW") ? widget.hymnsNew : widget.hymns;
        setState(() {
          _filteredHymns = currentHymns
              .where((h) => h.title.toLowerCase().contains(query.toLowerCase())
              || h.number.toString().replaceAll(new RegExp(r'[^\w\s]+'),'').contains(query.toLowerCase())
              || h.body.toLowerCase().replaceAll(new RegExp(r'[^\w\s]+'),'').contains(query.toLowerCase())
          ).toList();
        });
      },
    );
  }

  Widget _buildBody() {
    return new Container(
      margin: const EdgeInsets.fromLTRB(
          8.0,  // A left margin of 8.0
          8.0, // A top margin of 56.0
          8.0,  // A right margin of 8.0
          0.0   // A bottom margin of 0.0
      ),
      child: new Column(
        // A column widget can have several
        // widgets that are placed in a top down fashion
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Expanded(
                child: _getAppTitleWidget(),
              ),
              Container(
                width: 50.0,
                margin: EdgeInsets.only(left:5.0),
                child: RaisedButton(
                  color: Colors.black,
                  padding: EdgeInsets.all(4),

                  onPressed: () {
                    setState(() {
                      switch (filter) {
                        case "ALL":
                          filter = "OLD";
                          _filteredHymns =  widget.hymnsOld;
                          break;
                        case "OLD":
                          filter = "NEW";
                          _filteredHymns =  widget.hymnsNew;
                          break;
                        case "NEW":
                          filter = "ALL";
                          _filteredHymns =  widget.hymns;
                          break;
                      }
                    });
                  },
                  child: FittedBox(fit:BoxFit.fitWidth,
                    child: Column(
                      children: <Widget>[
                        Text(filter, style: TextStyle(fontSize: 16)),
                        const Text('Hymns', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          _getListViewWidget()
        ],
      ),
    );
  }

  Future<Null> refresh() {
    return new Future<Null>.value();
  }

  Widget _getListViewWidget() {
    return new Flexible(
        child: new RefreshIndicator(
            onRefresh: refresh,
            child: new ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filteredHymns.length,
                itemBuilder: _buildHymnItem
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: _buildBody(),
    );
  }
}
