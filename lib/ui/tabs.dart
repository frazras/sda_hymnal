import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sdahymnal/ui/settings.dart';
import 'package:sdahymnal/services/api.dart';

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  List<Hymn> _hymns = [];
  List<Hymn> _hymnsNew = [];
  List<Hymn> _hymnsOld = [];

  @override
  void initState() {
    super.initState();
    _loadHymns();
  }

  _loadHymns() async {
    String fileData =
        await DefaultAssetBundle.of(context).loadString("assets/hymns.json");
    setState(() {
      _hymns = HymnApi.allHymnsFromJson(fileData);
      _hymnsNew = _hymns.where((f) => f.version.contains('new')).toList();
      _hymnsOld = _hymns.where((f) => f.version.contains('old')).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(
                    child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.keyboard),
                      Text(" Numbers"),
                    ],
                  ),
                )),
                Tab(
                    child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.search),
                      Text("Search"),
                    ],
                  ),
                )),
                Tab(
                    child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.settings),
                      Text("Settings"),
                    ],
                  ),
                )),
              ],
            ),
            title: Container(
              padding: const EdgeInsets.only(top: 0.0),
              child: FittedBox(
                fit: BoxFit.fill,
                child: SvgPicture.asset(
                  "assets/logo.svg",
                  semanticsLabel: 'Hymnal Logo',
                  width: 900,
                  height: 300,
                ),
              ),
            ),
          ),
          body: TabBarView(
            children: [
              Buttons(hymnsOld: _hymnsOld, hymnsNew: _hymnsNew),
              HymnList(hymns: _hymns, hymnsOld: _hymnsOld, hymnsNew: _hymnsNew),
              const Settings()
            ],
          ),
        ),
      ),
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xffFFFFFF),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.grey[600],
        ),
      ),
    );
  }
}
