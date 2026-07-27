import 'package:flutter/material.dart';

import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/tabs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  await FontSizeController.instance.load();
  await Recents.instance.load();
  runApp(const Hymnal());
}

class Hymnal extends StatelessWidget {
  const Hymnal({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: 'Old & New SDA Hymnal',
        debugShowCheckedModeBanner: false,
        theme: buildHymnalTheme(HymnalTokens.light),
        darkTheme: buildHymnalTheme(HymnalTokens.dark),
        themeMode: mode,
        home: const Tabs(),
      ),
    );
  }
}
