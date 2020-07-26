import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sdahymnal/ui/settings.dart';


class Tabs extends StatelessWidget {
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
              Buttons(),
              HymnList(),
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