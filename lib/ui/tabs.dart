import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';
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
  int _tab = 0;
  bool _loadingStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingStarted) {
      _loadingStarted = true;
      _loadHymns();
    }
  }

  _loadHymns() async {
    String fileData =
        await DefaultAssetBundle.of(context).loadString("assets/hymns.json");
    if (!mounted) return;
    setState(() {
      _hymns = HymnApi.allHymnsFromJson(fileData);
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
                  ClassicHeader(active: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                    onFavorites: () => setState(() => _tab = 2))
                else
                  BrandHeader(onLogoTap: () => setState(() => _tab = 0)),
                Expanded(
                  // Both surrounding navigation widgets change with design.
                  // Keep the shared tab subtree when Flutter reconciles them.
                  key: const ValueKey('shared-tab-content'),
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      Buttons(hymnsOld: _hymnsOld, hymnsNew: _hymnsNew),
                      HymnList(
                          hymns: _hymns,
                          hymnsOld: _hymnsOld,
                          hymnsNew: _hymnsNew),
                      FavoritesTab(hymnsNew: _hymnsNew, hymnsOld: _hymnsOld),
                      const Settings(),
                    ],
                  ),
                ),
                if (t.isClassic)
                  SizedBox(height: MediaQuery.paddingOf(context).bottom)
                else
                  HymnalBottomNav(
                    active: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
