import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:sdahymnal/ui/fontsize.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => new _SettingsState();
}

class _SettingsState extends State<Settings> {


  @override
  void initState() {
    super.initState();
  }

  Widget _buildSettings() {
    var value = true;
    return SettingsList(
      sections: [
        SettingsSection(
          title: 'Settings',
          tiles: [
            SettingsTile(
              title: 'Font Size',
              //subtitle: 'English',
              leading: Icon(Icons.format_size),
              onTap: () {
                Navigator.push(
                    context,
                    swipe('left', FontSizer())
                );
              },
            ),
            SettingsTile(
              title: 'About Us',
              subtitle: 'Who made this App?',
              leading: Icon(Icons.person_pin),
              onTap: () {
                Navigator.push(
                    context,
                    swipe('left', FontSizer())
                );
              },
            ),
            SettingsTile(
              title: 'Donate',
              subtitle: 'Let me tell you why',
              leading: Icon(Icons.attach_money),
              onTap: () {
                Navigator.push(
                    context,
                    swipe('left', FontSizer())
                );
              },
            ),
            SettingsTile(
              title: 'Our Other Projects',
              subtitle: 'Like this app? You will love our ministry!',
              leading: Icon(Icons.favorite),
              onTap: () {
                Navigator.push(
                    context,
                    swipe('left', FontSizer())
                );
              },
            )
          ],
        ),
      ],
    );
  }
  PageRouteBuilder swipe(direction, page){
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(direction == "left" ? 1.0 : -1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: _buildSettings(),
    );
  }
}

