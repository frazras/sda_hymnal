import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sdahymnal/ui/settings.dart';
import 'package:sdahymnal/services/api.dart';


class Tabs extends StatefulWidget {
  @override
  _TabsState createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  List<Hymn> _hymns = [];
  List<Hymn> _hymnsNew = [];
  List<Hymn> _hymnsOld = [];

  @override
  void initState() {
    super.initState();
    _loadHymns();
    print("Hymns Loaded");
  }
  _loadHymns() async {
    String fileData = await DefaultAssetBundle.of(context).loadString("assets/hymns.json");
    setState(() {
      _hymns = HymnApi.allHymnsFromJson(fileData);
      _hymnsNew = _hymns.where((f) => f.version.contains('new')).toList();
      _hymnsOld = _hymns.where((f) => f.version.contains('old')).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    var _value = 0.0;
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [
                Tab(
                  child: FittedBox(fit:BoxFit.fitWidth,
                      child:Row(
                      children: <Widget>[
                        Icon(Icons.keyboard),
                        Text(" Numbers"),
                      ],
                    ),
                  )
                ),
                Tab(
                  child: FittedBox(fit:BoxFit.fitWidth,
                    child:Row(
                      children: <Widget>[
                        Icon(Icons.search),
                        Text("Search"),
                      ],
                    ),
                  )
                ),
                Tab(
                  child: FittedBox(fit:BoxFit.fitWidth,
                    child:Row(
                      children: <Widget>[
                        Icon(Icons.settings),
                        Text("Settings"),
                      ],
                    ),
                  )
                ),
]           ),
            title: Container(
              padding: EdgeInsets.only(top: 0.0),
              child: FittedBox(
                fit: BoxFit.fill,
                child: SvgPicture.asset(
                    "assets/logo.svg",
                    semanticsLabel: 'Hymnal Logo',
                    width: 900,
                ),
              ),
            ),
          ),
          body: TabBarView(
            children: [
              Buttons(hymnsOld: _hymnsOld, hymnsNew: _hymnsNew),
              HymnList(hymns: _hymns, hymnsOld:_hymnsOld, hymnsNew: _hymnsNew),
              Settings()
              //Icon(Icons.directions_bike),
            ],
          ),
        ),
      ),
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.dark,
        primaryColor: Color(0xffFFFFFF),
        scaffoldBackgroundColor: Colors.white,
        accentColor: Colors.grey[600],
      ),
    );
  }
}