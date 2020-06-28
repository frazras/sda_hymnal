import 'dart:async';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:flutter/material.dart';

class HymnList extends StatefulWidget {
  @override
  _HymnListState createState() => new _HymnListState();
}

class _HymnListState extends State<HymnList> {
  List<Hymn> _hymns = [];
  List<Hymn> _filtered_hymns = [];

  @override
  void initState() {
    super.initState();
    _loadHymns();
  }

  _loadHymns() async {
    String fileData = await DefaultAssetBundle.of(context).loadString("assets/hymns.json");
    setState(() {
      _hymns = HymnApi.allHymnsFromJson(fileData);
      _filtered_hymns = _hymns;
    });
  }

  Widget _buildHymnItem(BuildContext context, int index) {
    Hymn hymn = _filtered_hymns[index];

    return new Container(
      margin: const EdgeInsets.only(top: 5.0),
      child: new Card(
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Container (
              decoration: new BoxDecoration (
                  color: hymn.version == 'new' ? Colors.grey[700] : Colors.grey[400]
              ),
              child:  new ListTile(
                    //onTap: //TODO
                    title:  new Text(
                      hymn.number.toString() + '. '  +hymn.title,
                      style: new TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    subtitle: new Text(hymn.version.toUpperCase() + " Hymnal"),
                    //isThreeLine: true, // Less Cramped Tile
                    dense: false, // Less Cramped Tile

                  ),
            )
          ],
        ),
      ),
    );
  }

  Widget _getAppTitleWidget() {
    return new TextField(
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.all(10.0),
        hintText: "Search Hymns",
        hintStyle: TextStyle(fontSize: 20.0, color: Colors.lime),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Colors.lime,
        ),

      ),
      onChanged: (query){
        setState(() {
          _filtered_hymns = _hymns
              .where((h) => h.title.toLowerCase().contains(query.toLowerCase())
              || h.number.toString().contains(query.toLowerCase())
              || h.body.toLowerCase().contains(query.toLowerCase())
          ).toList();
        });
      },
    );
  }

  Widget _buildBody() {
    return new Container(
      margin: const EdgeInsets.fromLTRB(
          8.0,  // A left margin of 8.0
          56.0, // A top margin of 56.0
          8.0,  // A right margin of 8.0
          0.0   // A bottom margin of 0.0
      ),
      child: new Column(
        // A column widget can have several
        // widgets that are placed in a top down fashion
        children: <Widget>[
          _getAppTitleWidget(),
          _getListViewWidget()
        ],
      ),
    );
  }

  Future<Null> refresh() {
    _loadHymns();
    return new Future<Null>.value();
  }

  Widget _getListViewWidget() {
    return new Flexible(
        child: new RefreshIndicator(
            onRefresh: refresh,
            child: new ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filtered_hymns.length,
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
