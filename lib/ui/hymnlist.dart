import 'dart:async';
import 'package:flutter_html/style.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';


class HymnList extends StatefulWidget {
  @override
  _HymnListState createState() => new _HymnListState();
}

class _HymnListState extends State<HymnList> {
  List<Hymn> _hymns = [];
  List<Hymn> _filtered_hymns = [];
  List<Hymn> _hymns_new = [];
  List<Hymn> _hymns_old = [];

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
      _hymns_new = HymnApi.allHymnsFromJson(fileData, 'new');
      _hymns_old = HymnApi.allHymnsFromJson(fileData, 'old');
    });
  }

  Widget _buildHymnItem(BuildContext context, int index) {
    Hymn hymn = _filtered_hymns[index];

    return new Container(
      //margin: const EdgeInsets.only(top: 5.0),
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
                              builder: (context) => HymnPage(hymn: _filtered_hymns[index],
                                  hymns: _filtered_hymns[index].version == 'new' ?
                                          _hymns_new : _hymns_old ),
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
      /*decoration: BoxDecoration(
        contentPadding: EdgeInsets.all(1.0),
        hintText: "Search Hymns",
        hintStyle: TextStyle(fontSize: 20.0, color: Color(0xff00FF00)),
        border: OutlineInputBorder(),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xff00FF00),
          size: 40,
        ),

      ),*/
      onChanged: (query){
        setState(() {
          _filtered_hymns = _hymns
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
