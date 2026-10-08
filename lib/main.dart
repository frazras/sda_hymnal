import 'dart:ui';

import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/services/app_language.dart';

import 'package:flutter/material.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/analytics.dart';

import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/tabs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  await ThemeController.instance.load();
  await AppDesignController.instance.load();
  await FontSizeController.instance.load();
  await KeepScreenOn.instance.load();
  await AutoScroll.instance.load();
  await Autoplay.instance.load();
  await MusicPlayerVisible.instance.load();
  await Recents.instance.load();
  await Favorites.instance.load();
  await InstrumentTheme.instance.load();
  await MusicOptions.instance.load();
  await ChordTabs.instance.load();
  await ChordLevelPref.instance.load();
  await AppAnalytics.instance
      .initialize(design: AppDesignController.instance.value.name);
  final previousError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppAnalytics.instance.event('diagnostic', variant: 'flutter_error');
    previousError?.call(details);
  };
  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppAnalytics.instance.event('diagnostic', variant: 'platform_error');
    return previousPlatformError?.call(error, stack) ?? false;
  };
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
    AppAnalytics.instance.lifecycle(state == AppLifecycleState.resumed);
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
        AppLanguage.instance,
        ThemeController.instance,
        AppDesignController.instance,
      ]),
      builder: (context, _) => MaterialApp(
        title: 'Old & New SDA Hymnal',
        locale: AppLanguage.instance.value,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
