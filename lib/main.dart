import 'package:flutter/material.dart';

import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/tabs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  await AppDesignController.instance.load();
  await FontSizeController.instance.load();
  await KeepScreenOn.instance.load();
  await Recents.instance.load();
  await Favorites.instance.load();
  await InstrumentTheme.instance.load();
  await ChordTabs.instance.load();
  await ChordLevelPref.instance.load();
  runApp(const Hymnal());
}

class Hymnal extends StatefulWidget {
  const Hymnal({super.key});

  @override
  State<Hymnal> createState() => _HymnalState();
}

class _HymnalState extends State<Hymnal> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        AppDesignController.instance.syncIcon();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppDesignController.instance.syncIcon();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        AppDesignController.instance,
      ]),
      builder: (context, _) => MaterialApp(
        title: 'Old & New SDA Hymnal',
        debugShowCheckedModeBanner: false,
        theme: buildHymnalTheme(HymnalTokens.light,
            classic: AppDesignController.instance.value == AppDesign.classic),
        darkTheme: buildHymnalTheme(HymnalTokens.dark,
            classic: AppDesignController.instance.value == AppDesign.classic),
        themeMode: ThemeController.instance.value,
        home: const Tabs(),
      ),
    );
  }
}
