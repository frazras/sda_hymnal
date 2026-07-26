import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/donate.dart';
import 'package:sdahymnal/ui/sp.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/about.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Widget _buildSettings() {
    return SettingsList(
      sections: [
        SettingsSection(
          title: const Text('Settings'),
          tiles: [
            SettingsTile.navigation(
              title: const Text('Font Size'),
              leading: const Icon(Icons.format_size),
              onPressed: (context) {
                Navigator.push(context, swipe('left', const FontSizer()));
              },
            ),
            SettingsTile.navigation(
              title: const Text('About Us'),
              description: const Text('Who made this App?'),
              leading: const Icon(Icons.person_pin),
              onPressed: (context) {
                Navigator.push(context, swipe('left', const About()));
              },
            ),
            SettingsTile.navigation(
              title: const Text('Donate'),
              description: const Text('Let me tell you why'),
              leading: const Icon(Icons.attach_money),
              onPressed: (context) {
                Navigator.push(context, swipe('left', const Donate()));
              },
            ),
            SettingsTile.navigation(
              title: const Text('Our Other Projects'),
              description:
                  const Text('Like this app? You will love our ministry!'),
              leading: const Icon(Icons.favorite),
              onPressed: (context) {
                Navigator.push(context, swipe('left', const Sp()));
              },
            )
          ],
        ),
      ],
    );
  }

  PageRouteBuilder swipe(direction, page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(direction == "left" ? 1.0 : -1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildSettings(),
    );
  }
}
