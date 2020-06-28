import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:sdahymnal/ui/buttons.dart';

void main() {
  runApp(Hymnal());
}

class Hymnal extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text('BOld & New SDA Hymnal'),
        ),
        body: Buttons(),//HymnList(),
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.keyboard),
              title: Text('Number')
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.search),
                title: Text('Search')
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                title: Text('Settings')
            )
          ],
        ),
      ),
    theme: ThemeData(
      // Define the default brightness and colors.
        brightness: Brightness.dark,
        primaryColor: Color(0xff444444),
        scaffoldBackgroundColor: Colors.white,
        accentColor: Colors.grey[600],
      ),
    );
  }
}



