import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/models/hymn_video.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:sdahymnal/ui/settings.dart';
import 'package:sdahymnal/ui/saved_hymn_notice.dart';
import 'package:sdahymnal/ui/hymnal_browser.dart';

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
  List<HymnalPack> _packs = [];
  String _selectedBook = 'english';
  bool _searchAllBooks = false;
  bool _packsFailed = false;
  bool _contentLoaded = false;
  Future<void>? _selectionSave;

  HymnalPack? get _activePack {
    for (final pack in _packs) {
      if (pack.edition.id == _selectedBook) return pack;
    }
    return null;
  }

  void _selectBook(String id) {
    setState(() {
      _searchAllBooks = id == 'all';
      if (id != 'all') _selectedBook = id;
    });
    final previous = _selectionSave;
    _selectionSave = () async {
      if (previous != null) await previous;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (id != 'all') await prefs.setString('selectedHymnal', id);
        await prefs.setBool('searchAllHymnals', id == 'all');
      } catch (_) {
        // The selected book remains usable even if its preference cannot save.
      }
    }();
  }

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
    List<HymnalPack> packs = [];
    var packsFailed = false;
    try {
      packs = await loadHymnalPacks(bundle);
    } catch (_) {
      packsFailed = true;
    }
    final selected =
        (await SharedPreferences.getInstance()).getString('selectedHymnal') ??
            'english';
    final searchAll =
        (await SharedPreferences.getInstance()).getBool('searchAllHymnals') ??
            false;
    if (!mounted) return;
    setState(() {
      _packs = packs;
      _packsFailed = packsFailed;
      _searchAllBooks = searchAll;
      _selectedBook =
          packs.any((p) => p.edition.id == selected) ? selected : 'english';
      _hymns = HymnApi.allHymnsFromJson(
        hymnData,
        metadata: metadata,
        videos: videos,
      );
      final repository = HymnalRepository(editions: [
        HymnalEdition.englishNew,
        HymnalEdition.englishOld,
        ...packs.map((p) => p.edition)
      ], hymns: [
        ..._hymns,
        ...packs.expand((p) => p.hymns)
      ], readings: _readings.readings);
      _hymnsNew = repository.hymnsFor('sda-en-1985');
      _hymnsOld = repository.hymnsFor('sda-en-1941');
      _contentLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final typing =
        (_tab == 1 || (_activePack != null && _tab == 0)) && keyboardInset > 0;
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
                if (!typing && t.isClassic)
                  ClassicHeader(
                      active: _tab,
                      onSelect: _selectTab,
                      onFavorites: () => _selectTab(2))
                else if (!typing)
                  BrandHeader(onLogoTap: () => _selectTab(0)),
                const SavedHymnNotice(),
                if (!typing && _tab <= 1 && _packs.isNotEmpty)
                  HymnalSelector(
                      packs: _packs,
                      value:
                          _tab == 1 && _searchAllBooks ? 'all' : _selectedBook,
                      allowAll: _tab == 1,
                      onChanged: _selectBook),
                if (_tab == 1 && _packsFailed)
                  TextButton(
                      onPressed: _loadHymns,
                      child:
                          const Text('Additional hymnals unavailable · Retry')),
                Expanded(
                  // Both surrounding navigation widgets change with design.
                  // Keep the shared tab subtree when Flutter reconciles them.
                  key: const ValueKey('shared-tab-content'),
                  child: !_contentLoaded
                      ? const Center(child: CircularProgressIndicator())
                      : IndexedStack(
                          index: _tab,
                          children: [
                            if (_activePack case final pack?)
                              HymnalBrowser(
                                  key: ValueKey('numbers-${pack.edition.id}'),
                                  pack: pack,
                                  keyboardOpen: typing && _tab == 0,
                                  numbersOnly: true)
                            else
                              LayoutBuilder(
                                  builder: (context, bounds) => OverflowBox(
                                      alignment: Alignment.topCenter,
                                      minHeight:
                                          bounds.maxHeight + keyboardInset,
                                      maxHeight:
                                          bounds.maxHeight + keyboardInset,
                                      child: Buttons(
                                          active: _tab == 0,
                                          hymnsOld: _hymnsOld,
                                          hymnsNew: _hymnsNew,
                                          additionalReadings: _readings))),
                            if (_searchAllBooks)
                              AllHymnalsSearch(hymns: [
                                ..._hymns,
                                ..._packs.expand((p) => p.hymns)
                              ], keyboardOpen: typing && _tab == 1)
                            else if (_activePack case final pack?)
                              HymnalBrowser(
                                  key: ValueKey('search-${pack.edition.id}'),
                                  keyboardOpen: typing && _tab == 1,
                                  pack: pack)
                            else
                              HymnList(
                                  active: _tab == 1,
                                  additionalReadings: _readings,
                                  hymns: _hymns,
                                  hymnsOld: _hymnsOld,
                                  hymnsNew: _hymnsNew),
                            FavoritesTab(
                                hymnsNew: _hymnsNew,
                                hymnsOld: _hymnsOld,
                                additionalHymns:
                                    _packs.expand((p) => p.hymns).toList()),
                            Settings(hymns: _hymns, historyHymns: [
                              ..._hymns,
                              ..._packs.expand((p) => p.hymns),
                            ]),
                          ],
                        ),
                ),
                if (!typing && t.isClassic)
                  SizedBox(height: MediaQuery.paddingOf(context).bottom)
                else if (!typing)
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
