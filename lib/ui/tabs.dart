import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/models/hymn_video.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:sdahymnal/ui/settings.dart';

/// App shell: brand header + active tab + bottom nav.
/// Tab screens are content-only; the header and nav live here.
class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  List<Hymn> _hymns = [];
  List<Hymn> _hymnsNew = [];
  List<Hymn> _hymnsOld = [];
  AdditionalReadingCatalog _readings = const AdditionalReadingCatalog([]);
  int _tab = 0;
  bool _loadingStarted = false;
  bool _releaseCheckStarted = false;

  void _selectTab(int tab) {
    if (tab == _tab) return;
    AppAnalytics.instance
        .screen(['numbers', 'search', 'favorites', 'settings'][tab]);
    setState(() => _tab = tab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingStarted) {
      _loadingStarted = true;
      _loadHymns();
    }
    if (!_releaseCheckStarted) {
      _releaseCheckStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ReleaseNotesService.instance.showIfNeeded(context);
      });
    }
  }

  _loadHymns() async {
    final bundle = DefaultAssetBundle.of(context);
    final hymnData = await bundle.loadString('assets/hymns.json');
    try {
      final readingsData =
          await bundle.loadString('assets/additional_readings.json');
      _readings = AdditionalReadingCatalog.fromJson(
          jsonDecode(readingsData) as Map<String, dynamic>);
    } on FlutterError {
      _readings = const AdditionalReadingCatalog([]);
    }
    HymnMetadataCatalog? metadata;
    HymnVideoCatalog? videos;
    try {
      final metadataData = await bundle.loadString('assets/hymn_metadata.json');
      metadata = HymnMetadataCatalog.fromJson(metadataData);
    } on FlutterError {
      AppAnalytics.instance.event('diagnostic', variant: 'content_load');
      // Some embedders and lightweight widget-test bundles provide only the
      // legacy hymn asset. Lyrics remain usable while metadata is optional.
      metadata = null;
    }
    try {
      final videoData = await bundle.loadString('assets/hymn_videos.json');
      videos = HymnVideoCatalog.fromJson(videoData);
    } on FlutterError {
      AppAnalytics.instance.event('diagnostic', variant: 'content_load');
      // Playback remains optional for lightweight test bundles and offline
      // builds that intentionally ship only the lyrics asset.
      videos = null;
    }
    if (!mounted) return;
    setState(() {
      _hymns = HymnApi.allHymnsFromJson(
        hymnData,
        metadata: metadata,
        videos: videos,
      );
      _hymnsNew = _hymns.where((f) => f.version.contains('new')).toList();
      _hymnsOld = _hymns.where((f) => f.version.contains('old')).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: Stack(
        children: [
          // Dark-mode radial glow behind the top of the Numbers screen:
          // radial-gradient(560px 300px at 50% -90px, rgba(30,138,99,0.18), 70%)
          if (t.isDark && !t.isClassic && _tab == 0)
            Positioned(
              top: -90,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Transform.scale(
                    scaleY: 300 / 560,
                    child: Container(
                      width: 560,
                      height: 560,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0x2E1E8A63), Color(0x001E8A63)],
                          stops: [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (t.isClassic)
                  ClassicHeader(
                      active: _tab,
                      onSelect: _selectTab,
                      onFavorites: () => _selectTab(2))
                else
                  BrandHeader(onLogoTap: () => _selectTab(0)),
                Expanded(
                  // Both surrounding navigation widgets change with design.
                  // Keep the shared tab subtree when Flutter reconciles them.
                  key: const ValueKey('shared-tab-content'),
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      Buttons(
                          active: _tab == 0,
                          hymnsOld: _hymnsOld,
                          hymnsNew: _hymnsNew,
                          additionalReadings: _readings),
                      HymnList(
                          active: _tab == 1,
                          additionalReadings: _readings,
                          hymns: _hymns,
                          hymnsOld: _hymnsOld,
                          hymnsNew: _hymnsNew),
                      FavoritesTab(hymnsNew: _hymnsNew, hymnsOld: _hymnsOld),
                      Settings(hymns: _hymns),
                    ],
                  ),
                ),
                if (t.isClassic)
                  SizedBox(height: MediaQuery.paddingOf(context).bottom)
                else
                  HymnalBottomNav(
                    active: _tab,
                    onSelect: _selectTab,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
