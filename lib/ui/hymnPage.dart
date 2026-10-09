import 'package:sdahymnal/l10n/app_text.dart';
import 'dart:async';
import '../services/playback_continuation.dart';
import '../services/error_reports.dart';

import 'report_error.dart';
import 'favorite_lists.dart';
import 'saved_hymn_notice.dart';
import 'hymn_page_turn.dart';
import 'hymn_sheet_music.dart';
import 'hymn_share.dart';
// ignore_for_file: file_names

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sdahymnal/ui/music_options.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'musical_style_sheet.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/screen_wake.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/favorite_burst.dart';
import 'package:sdahymnal/ui/hymn_auto_scroll.dart';
import 'package:sdahymnal/ui/hymn_story_page.dart';
import 'package:sdahymnal/ui/hymn_video_overlay.dart';

import 'reader_sequence.dart';

export 'reader_sequence.dart' show HymnContinuation;

/// Hymn reading page (full-screen sub-page, pushed with slideRoute).
///
/// Header: crumb + number/title stack, player visibility, favorite, "Aa".
/// Body: hymn HTML at the user's font size, max-width 560, centered.
/// Floating player bar: prev/next, key pill (transpose sheet), seek ±10,
/// play/pause, speed pill — key/play/speed dimmed on Old-Hymnal pages.
class HymnPage extends StatefulWidget {
  final Hymn hymn;
  final List<Hymn> hymns;
  final String analyticsSource;

  /// Cycle through [hymns] in displayed category order instead of by number.
  final String? categoryTitle;
  final ReaderSequence? sequence;

  /// Same reader layout, without history, playback or screen-wake effects.
  final bool previewOnly;
  final HymnContinuation? continuation;
  final bool showSheetMusic;

  bool get cycleCategory => categoryTitle != null;

  const HymnPage(
      {super.key,
      required this.hymn,
      required this.hymns,
      this.analyticsSource = 'unknown',
      this.categoryTitle,
      this.sequence,
      this.previewOnly = false,
      this.showSheetMusic = false,
      this.continuation});

  @override
  State<HymnPage> createState() => _HymnPageState();
}

enum _ReaderAction {
  shareLyrics,
  reportError,
  video,
  player,
  scrollSpeed,
  chords,
  fontSize,
  musicalStyle,
  choirPractice,
  sheetMusic
}

class _HymnPageState extends State<HymnPage> {
  late bool _sheetMusicVisible = widget.showSheetMusic;
  bool _videoVisible = false;
  bool _advancing = false;
  StreamSubscription<MidiPlayback>? _completionSubscription;
  final _favoriteBurst = GlobalKey<FavoriteBurstState>();
  bool _endHintShown = false;

  void _toggleFavorite() {
    saveFavorite(context, widget.hymn);
    _favoriteBurst.currentState?.play(context.tokens.accent);
  }

  bool _onLyricsScroll(ScrollNotification notification) {
    if (!_endHintShown &&
        notification.depth == 0 &&
        notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) > 0 &&
        notification.metrics.maxScrollExtent > 0 &&
        notification.metrics.extentAfter <= 2) {
      _endHintShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !Favorites.instance
                .containsAnywhere(widget.hymn.number, widget.hymn.version)) {
          _favoriteBurst.currentState?.play(const Color(0xFFE53935));
        }
      });
    }
    return false;
  }

  final _autoScrollController = HymnAutoScrollController();

  bool get _showPlayer => MusicPlayerVisible.instance.value;

  @override
  void initState() {
    super.initState();
    if (widget.previewOnly) return;
    _completionSubscription =
        MidiPlayer.instance.completions.listen((finished) {
      if (finished.n == widget.hymn.number &&
          finished.version == widget.hymn.version &&
          !_videoVisible) {
        _continue(HymnContinuation.midi);
      }
    });
    AppAnalytics.instance.openHymn(
        widget.hymn.number, widget.hymn.version, widget.analyticsSource);
    // Single recents recording point: every open (keypad, search, chip) and
    // every prev/next/swipe move constructs a new HymnPage, so this covers
    // them all.
    // The outgoing Numbers screen may still be building during navigation.
    // Publish after the frame, not while its recents builder is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Recents.instance.push(widget.hymn);
    });
    // Publishes this hymn's written key for the key pill and resets the
    // transposition when the page moved to a different hymn.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await MidiPlayer.instance.prepareKey(widget.hymn);
      if (!mounted ||
          !Autoplay.instance.value ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      if (widget.continuation == HymnContinuation.video) {
        _showVideo();
      } else if (widget.continuation == HymnContinuation.midi &&
          MidiPlayer.instance.current.value == null) {
        await _toggleMusic();
      }
    });
    // Reading is the one place worth fighting the lock timer: the phone is
    // propped up and untouched for a whole hymn. Honours the setting.
    ScreenWake.instance.acquire();
  }

  @override
  void dispose() {
    if (widget.previewOnly) {
      super.dispose();
      return;
    }
    _completionSubscription?.cancel();
    AppAnalytics.instance.closeHymn(widget.hymn.number, widget.hymn.version);
    // Leaving the page (back, or prev/next replacing it) stops its playback;
    // guarded so it never cuts off a newer page that already started its own.
    if (!_advancing) MidiPlayer.instance.stopIfCurrent(widget.hymn);
    ScreenWake.instance.release();
    super.dispose();
  }

  void _showVideo() {
    if (widget.hymn.video == null) return;
    AppAnalytics.instance.event('video_open',
        hymn: widget.hymn.number, edition: widget.hymn.version);
    MidiPlayer.instance.stopIfCurrent(widget.hymn);
    setState(() => _videoVisible = true);
  }

  void _closeVideo() {
    AppAnalytics.instance.event('video_close',
        hymn: widget.hymn.number, edition: widget.hymn.version);
    setState(() => _videoVisible = false);
  }

  void _continue(HymnContinuation medium) {
    if (!mounted ||
        _advancing ||
        !Autoplay.instance.value ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    if (medium == HymnContinuation.video && !_videoVisible) return;
    if (widget.sequence != null) {
      final page = widget.sequence!
          .page(1, continuation: medium, showSheetMusic: _sheetMusicVisible);
      if (page == null) return;
      _advancing = true;
      Navigator.pushReplacement(
          context,
          PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => page));
      return;
    }
    final target = nextPlayableHymn(
        widget.hymns,
        widget.hymn,
        (h) => medium == HymnContinuation.video
            ? h.video != null
            : MidiPlayer.hasMusic(h));
    if (target == null) return;
    _advancing = true;
    Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => HymnPage(
              hymn: target,
              hymns: widget.hymns,
              categoryTitle: widget.categoryTitle,
              analyticsSource: 'adjacent',
              showSheetMusic: _sheetMusicVisible,
              continuation: medium),
        ));
  }

  /// Navigate to the adjacent hymn: dir = -1 previous, 1 next.
  /// Categories wrap in list order; full hymnals stop at their ends.
  /// Numbers the hymnal does not carry are stepped over rather than landed
  /// on — see [adjacentHymn].
  Hymn? _adjacent(int dir) {
    if (widget.cycleCategory) {
      final index = widget.hymns.indexWhere((h) =>
          h.number == widget.hymn.number && h.version == widget.hymn.version);
      if (index < 0 || widget.hymns.length < 2) return null;
      return widget.hymns[(index + dir) % widget.hymns.length];
    }
    final book = widget.hymns
        .where((h) => h.version == widget.hymn.version)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final index = book.indexWhere((h) => h.number == widget.hymn.number);
    final target = index + dir;
    return index >= 0 && target >= 0 && target < book.length
        ? book[target]
        : null;
  }

  bool _canMove(int dir) =>
      widget.sequence?.canMove(dir) ?? (_adjacent(dir) != null);

  void _move(int dir, {bool turned = false}) {
    if (widget.sequence != null) {
      final page =
          widget.sequence!.page(dir, showSheetMusic: _sheetMusicVisible);
      if (page != null) {
        Navigator.pushReplacement(
            context,
            turned
                ? PageRouteBuilder<void>(
                    transitionDuration: Duration.zero,
                    pageBuilder: (_, __, ___) => page)
                : slideRoute(page, fromLeft: dir < 0));
      }
      return;
    }
    final target = _adjacent(dir);
    if (target == null) return;
    final page = HymnPage(
        hymn: target,
        hymns: widget.hymns,
        categoryTitle: widget.categoryTitle,
        showSheetMusic: _sheetMusicVisible,
        analyticsSource: 'adjacent');
    Navigator.pushReplacement(
      context,
      turned
          ? PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => page)
          : slideRoute(page, fromLeft: dir < 0),
    );
  }

  @override
  Widget build(BuildContext context) => widget.previewOnly || _sheetMusicVisible
      ? _reader(context)
      : HymnPageTurn(
          previewBuilder: (dir) {
            if (widget.sequence != null) {
              return widget.sequence!.page(dir, previewOnly: true);
            }
            final hymn = _adjacent(dir);
            return hymn == null ? null : _turnPreview(context, hymn);
          },
          onTurn: (dir) => _move(dir, turned: true),
          child: _reader(context),
        );

  Widget _turnPreview(BuildContext context, Hymn hymn) => HymnPage(
        key: const ValueKey('hymn-turn-preview'),
        hymn: hymn,
        hymns: widget.hymns,
        categoryTitle: widget.categoryTitle,
        previewOnly: true,
      );

  Widget _reader(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        },
        child: Focus(
          autofocus: !widget.previewOnly,
          child: SafeArea(
            child: Column(
              children: [
                if (t.isClassic)
                  _classicHeader(t)
                else
                  SubPageHeader(
                    center: _headerCenter(t),
                    trailing: _headerActions(t),
                  ),
                if (!widget.previewOnly) const SavedHymnNotice(),
                if (widget.categoryTitle != null || widget.sequence != null)
                  Container(
                    key: const ValueKey('hymn-category-indicator'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(bottom: BorderSide(color: t.line2)),
                    ),
                    child: Text(
                      widget.sequence?.labelFor(context) ??
                          'Category: ${widget.categoryTitle} · ${widget.hymns.indexWhere((h) => h.number == widget.hymn.number && h.version == widget.hymn.version) + 1} of ${widget.hymns.length}',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 13, color: t.accent),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (_videoVisible && widget.hymn.video != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: HymnVideoOverlay(
                                video: widget.hymn.video!,
                                onClose: _closeVideo,
                                onEnded: () =>
                                    _continue(HymnContinuation.video),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: _sheetMusicVisible
                            ? Column(children: [
                                Expanded(
                                  child: HymnSheetMusic(
                                    hymn: widget.hymn,
                                    onLyrics: () => setState(
                                        () => _sheetMusicVisible = false),
                                  ),
                                ),
                                if (MidiPlayer.hasMusic(widget.hymn) &&
                                    _showPlayer &&
                                    !_videoVisible)
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                    child: _playerBar(t),
                                  ),
                              ])
                            : HymnAutoScroll(
                                previewOnly: widget.previewOnly,
                                key: ValueKey(
                                    '${widget.hymn.version}-${widget.hymn.number}'),
                                hymn: widget.hymn,
                                controller: _autoScrollController,
                                builder: (controller, scrollControls) => t
                                        .isClassic
                                    ? Column(children: [
                                        Expanded(
                                            child: _scrollArea(
                                                t, controller, scrollControls)),
                                        if (MidiPlayer.hasMusic(widget.hymn) &&
                                            _showPlayer &&
                                            !_videoVisible)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                8, 0, 8, 8),
                                            child: _playerBar(t),
                                          ),
                                      ])
                                    : Stack(
                                        children: [
                                          Positioned.fill(
                                              child: _scrollArea(t, controller,
                                                  scrollControls)),
                                          if (MidiPlayer.hasMusic(
                                                  widget.hymn) &&
                                              _showPlayer &&
                                              !_videoVisible)
                                            Positioned(
                                              left: 16,
                                              right: 16,
                                              bottom: 18,
                                              child: _playerBar(t),
                                            ),
                                        ],
                                      ),
                              ),
                      ),
                      if (!MidiPlayer.hasMusic(widget.hymn) ||
                          !_showPlayer ||
                          _videoVisible)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                  key: const ValueKey('reader-previous'),
                                  tooltip: widget.sequence == null
                                      ? context.appText.previousHymn
                                      : context.appText.previousItem,
                                  onPressed:
                                      !_canMove(-1) ? null : () => _move(-1),
                                  icon: const Icon(Icons.chevron_left)),
                              Expanded(
                                  child: Text(context.appText.swipeToTurn,
                                      textAlign: TextAlign.center,
                                      maxLines: 2)),
                              IconButton(
                                  key: const ValueKey('reader-next'),
                                  tooltip: widget.sequence == null
                                      ? context.appText.nextHymn
                                      : context.appText.nextItem,
                                  onPressed:
                                      !_canMove(1) ? null : () => _move(1),
                                  icon: const Icon(Icons.chevron_right)),
                            ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _classicHeader(HymnalTokens t) => Container(
        key: const ValueKey('classic-reader-header'),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Row(children: [
          const BackButton(),
          Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!widget.hymn.isEnglishEdition)
              Text(widget.hymn.bookLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.muted, fontSize: 11)),
            Text(
              '${widget.hymn.number} ${widget.hymn.title}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.ink, fontSize: 18, fontWeight: FontWeight.bold),
            )
          ])),
          _headerActions(t),
        ]),
      );

  Widget _headerActions(HymnalTokens t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [_favoriteHeaderButton(t), _readerMenu(t)],
      );

  Widget _favoriteHeaderButton(HymnalTokens t) => AnimatedBuilder(
        animation:
            Listenable.merge([Favorites.instance, Favorites.instance.sublists]),
        builder: (context, _) {
          final favorite = Favorites.instance
              .containsAnywhere(widget.hymn.number, widget.hymn.version);
          return IconButton(
            key: const ValueKey('hymn-favorite-header-button'),
            tooltip: Favorites.instance.sublists.value.isNotEmpty
                ? context.appText.saveToFavoriteLists
                : favorite
                    ? context.appText.removeFavorite
                    : context.appText.addFavorite,
            visualDensity: VisualDensity.compact,
            icon: FavoriteBurst(
              key: _favoriteBurst,
              favorite: favorite,
              color: favorite ? t.accent : t.ink,
            ),
            onPressed: _toggleFavorite,
          );
        },
      );

  Widget _readerMenu(HymnalTokens t) {
    return ValueListenableBuilder<bool>(
      valueListenable: ChordTabs.instance,
      builder: (context, chordsVisible, _) {
        return PopupMenuButton<_ReaderAction>(
          key: const ValueKey('hymn-reader-options'),
          tooltip: context.appText.readerOptions,
          color: t.isDark ? const Color(0xFF1C2721) : t.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          icon: Icon(Icons.more_vert, color: t.ink),
          onSelected: (action) {
            switch (action) {
              case _ReaderAction.shareLyrics:
                Navigator.push(
                    context, slideRoute(HymnSharePage(hymn: widget.hymn)));
              case _ReaderAction.sheetMusic:
                setState(() => _sheetMusicVisible = !_sheetMusicVisible);
              case _ReaderAction.reportError:
                Navigator.push(
                    context,
                    slideRoute(ReportErrorPage(
                        subject: widget.hymn.isEnglishEdition
                            ? ErrorReportSubject(
                                kind: 'hymn',
                                title: widget.hymn.title,
                                edition: widget.hymn.version,
                                number: widget.hymn.number,
                                itemId:
                                    '${widget.hymn.version}:${widget.hymn.number}',
                              )
                            : ErrorReportSubject(
                                title:
                                    '${widget.hymn.bookLabel} · ${widget.hymn.number} · ${widget.hymn.title}'))));
              case _ReaderAction.musicalStyle:
                showMusicalStyleSheet(context);
              case _ReaderAction.choirPractice:
                final enabled = !MusicOptions.instance.choirPractice;
                MusicOptions.instance.setChoirPractice(enabled);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(enabled
                      ? context.appText.choirPracticeOn
                      : context.appText.choirPracticeOff),
                ));
              case _ReaderAction.video:
                _showVideo();
              case _ReaderAction.player:
                MusicPlayerVisible.instance.set(!_showPlayer);
                setState(() {});
              case _ReaderAction.scrollSpeed:
                if (!AutoScroll.instance.value) AutoScroll.instance.set(true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _autoScrollController.showControls();
                });
              case _ReaderAction.chords:
                final show = !ChordTabs.instance.value;
                ChordTabs.instance.set(show);
                if (show && !_showPlayer) {
                  MusicPlayerVisible.instance.set(true);
                  setState(() {});
                }
              case _ReaderAction.fontSize:
                Navigator.push(context, slideRoute(const FontSizer()));
            }
          },
          itemBuilder: (context) => [
            if (widget.hymn.isEnglishEdition ||
                widget.hymn.version == 'sda-es-2009' ||
                widget.hymn.version == 'sda-ru-1997')
              PopupMenuItem(
                key: const ValueKey('hymn-sheet-music'),
                value: _ReaderAction.sheetMusic,
                child: _menuLabel(
                    t,
                    Icons.library_music_outlined,
                    _sheetMusicVisible
                        ? context.appText.showLyrics
                        : context.appText.sheetMusic),
              ),
            if (MidiPlayer.hasMidi(widget.hymn)) ...[
              PopupMenuItem(
                key: const ValueKey('hymn-musical-style'),
                value: _ReaderAction.musicalStyle,
                child: _menuLabel(
                    t, Icons.music_note, context.appText.musicalStyle),
              ),
              CheckedPopupMenuItem(
                key: const ValueKey('hymn-choir-practice'),
                value: _ReaderAction.choirPractice,
                checked: MusicOptions.instance.choirPractice,
                child: Text(context.appText.choirPractice),
              ),
            ],
            if (widget.hymn.video != null)
              PopupMenuItem(
                key: const ValueKey('hymn-youtube-button'),
                value: _ReaderAction.video,
                child: _menuLabel(
                  t,
                  _videoVisible
                      ? Icons.smart_display
                      : Icons.smart_display_outlined,
                  _videoVisible
                      ? context.appText.restartHymnVideo
                      : context.appText.playHymnVideo,
                ),
              ),
            if (MidiPlayer.hasMusic(widget.hymn))
              PopupMenuItem(
                key: const ValueKey('hymn-player-visibility'),
                value: _ReaderAction.player,
                child: _menuLabel(
                  t,
                  _showPlayer
                      ? Icons.music_off_outlined
                      : Icons.music_note_outlined,
                  _showPlayer
                      ? context.appText.hideMusicPlayer
                      : context.appText.showMusicPlayer,
                ),
              ),
            if (!_sheetMusicVisible &&
                (MidiPlayer.hasMusic(widget.hymn) ||
                    !widget.hymn.isEnglishEdition))
              PopupMenuItem(
                key: const ValueKey('hymn-scroll-speed-menu-item'),
                value: _ReaderAction.scrollSpeed,
                child: _menuLabel(
                    t,
                    Icons.speed,
                    AutoScroll.instance.value
                        ? context.appText.scrollSpeed
                        : context.appText.autoScroll),
              ),
            if (MidiPlayer.hasMidi(widget.hymn))
              PopupMenuItem(
                key: const ValueKey('hymn-chord-tabs'),
                value: _ReaderAction.chords,
                child: _menuLabel(
                  t,
                  Icons.piano,
                  chordsVisible
                      ? context.appText.hideChordTabs
                      : context.appText.showChordTabs,
                ),
              ),
            if (!_sheetMusicVisible)
              PopupMenuItem(
                key: const ValueKey('hymn-font-size-button'),
                value: _ReaderAction.fontSize,
                child:
                    _menuLabel(t, Icons.text_fields, context.appText.textSize),
              ),
            PopupMenuItem(
                key: const ValueKey('hymn-share-lyrics'),
                value: _ReaderAction.shareLyrics,
                child: _menuLabel(t, Icons.share_outlined,
                    context.appText.copyOrShareLyrics)),
            PopupMenuItem(
                value: _ReaderAction.reportError,
                child: _menuLabel(t, Icons.report_problem_outlined,
                    context.appText.reportErrors)),
          ],
        );
      },
    );
  }

  Widget _menuLabel(HymnalTokens t, IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20, color: t.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.ink, fontFamily: kSans),
            ),
          ),
        ],
      );

  Widget _headerCenter(HymnalTokens t) {
    final crumb = widget.hymn.bookLabel.toUpperCase();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          crumb,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: trackingEm(0.14, 10),
            color: t.muted,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${widget.hymn.number}',
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                widget.hymn.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: t.ink,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Body
  // -------------------------------------------------------------------------

  Widget _scrollArea(
      HymnalTokens t, ScrollController controller, Widget scrollControls) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onLyricsScroll,
      child: SingleChildScrollView(
        key: const ValueKey('hymn-lyrics-scroll'),
        controller: controller,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: t.isClassic
                  ? const EdgeInsets.all(16)
                  : EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MidiPlayer.hasMusic(widget.hymn) &&
                              _showPlayer &&
                              !_videoVisible
                          ? 150
                          : 26,
                    ),
              child: ValueListenableBuilder<double>(
                valueListenable: FontSizeController.instance,
                builder: (context, fontSize, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _hymnInfo(t)),
                        if (AutoScroll.instance.value) ...[
                          const SizedBox(width: 6),
                          scrollControls,
                        ],
                      ],
                    ),
                    Html(
                      data: styleHymnBody(widget.hymn.readingBody, t, fontSize),
                      style: {
                        'html': Style(
                          fontFamily: t.isClassic ? 'Roboto' : kSerif,
                          fontSize: FontSize(fontSize),
                          lineHeight: LineHeight(t.isClassic ? 1.45 : 1.7),
                          color: t.ink,
                        ),
                        'body': Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                      },
                    ),
                    Padding(
                      key: const ValueKey('hymn-end-mark'),
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Semantics(
                        label: context.appText.endOfHymn,
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 32, child: Divider(color: t.line)),
                            const SizedBox(width: 14),
                            HymnalIcons.logoMark(t, size: 22),
                            const SizedBox(width: 9),
                            Text(
                              context.appText.end,
                              style: TextStyle(
                                fontFamily: 'PinyonScript',
                                fontSize: 32,
                                height: 1,
                                letterSpacing: 1,
                                color: t.accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(width: 32, child: Divider(color: t.line)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hymnInfo(HymnalTokens t) {
    final metadata = widget.hymn.metadata;
    if (metadata == null) {
      final credits = widget.hymn.credits;
      if (credits == null || credits.isEmpty) return const SizedBox.shrink();
      return Text(credits, style: TextStyle(color: t.muted, fontSize: 12));
    }
    final authors = metadata.authorsFor(
      widget.hymn.version,
      widget.hymn.number,
    );
    final composers = metadata.composersFor(
      widget.hymn.version,
      widget.hymn.number,
    );
    final textStyle = TextStyle(
      fontFamily: kSans,
      fontSize: 11,
      height: 1.25,
      color: t.muted,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        runSpacing: 0,
        children: [
          Text(
            context.appText.wordsCredit(authors.isEmpty
                ? context.appText.notDocumented
                : authors.join(', ')),
            style: textStyle,
          ),
          if (composers.isNotEmpty) Text('•', style: textStyle),
          if (composers.isNotEmpty)
            Text(context.appText.musicCredit(composers.join(', ')),
                style: textStyle),
          if (metadata.stories.isNotEmpty) Text('•', style: textStyle),
          if (metadata.stories.isNotEmpty)
            Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('hymn-story-link'),
                onTap: () {
                  AppAnalytics.instance.event('story_open',
                      hymn: widget.hymn.number, edition: widget.hymn.version);
                  Navigator.push(
                    context,
                    slideRoute(HymnStoryPage(hymn: widget.hymn)),
                  );
                },
                child: Text(
                  context.appText.readStories(metadata.stories.length),
                  style: textStyle.copyWith(
                    color: t.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: t.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Floating player bar
  // -------------------------------------------------------------------------

  Widget _playerBar(HymnalTokens t) {
    return Container(
      key: const ValueKey('hymn-music-player'),
      // Shadow lives outside the clip so it is not cut off by ClipRRect.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: t.barShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.barBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MidiPlayer.hasMidi(widget.hymn))
                  ChoirPartsButton(hymn: widget.hymn),
                _chordStrip(t),
                _progressLine(t),
                // FittedBox lets the whole control strip scale down as one
                // unit on narrow screens instead of overflowing.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        t,
                        key: const ValueKey('reader-previous'),
                        onTap: () => _move(-1),
                        icon: HymnalIcons.backChevron(t.ink, size: 16),
                      ),
                      const SizedBox(width: 10),
                      if (MidiPlayer.hasMidi(widget.hymn)) _keyPill(t),
                      const SizedBox(width: 10),
                      _seekButton(t, forward: false),
                      const SizedBox(width: 10),
                      _playButton(t),
                      const SizedBox(width: 10),
                      _seekButton(t, forward: true),
                      const SizedBox(width: 10),
                      _speedPill(t),
                      const SizedBox(width: 10),
                      _circleButton(
                        t,
                        key: const ValueKey('reader-next'),
                        onTap: () => _move(1),
                        icon: HymnalIcons.forwardChevron(t.ink, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thin progress line across the bar while this hymn's MIDI is loaded.
  Widget _progressLine(HymnalTokens t) {
    return ValueListenableBuilder<MidiPlayback?>(
      valueListenable: MidiPlayer.instance.current,
      builder: (context, cur, _) {
        if (!MidiPlayer.isCurrent(cur, widget.hymn)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ValueListenableBuilder<Duration>(
            valueListenable: MidiPlayer.instance.duration,
            builder: (context, dur, _) => ValueListenableBuilder<Duration>(
              valueListenable: MidiPlayer.instance.position,
              builder: (context, pos, _) {
                final frac = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 3,
                    color: t.surface2,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(color: t.accent),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Chord tabs (live strip + chart sheet)
  // -------------------------------------------------------------------------

  /// Live chord strip above the progress line: the current chord and the next
  /// two, sliding left as playback advances. Shown only when the Chord-tabs
  /// setting is on and this hymn's tune yielded a chord track; before play it
  /// previews the opening chords. Tap opens the full chord chart sheet.
  Widget _chordStrip(HymnalTokens t) {
    if (!MidiPlayer.hasMidi(widget.hymn)) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: ChordTabs.instance,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<ChordTrack?>(
          valueListenable: MidiPlayer.instance.chordTrack,
          builder: (context, raw, _) {
            if (raw == null) return const SizedBox.shrink();
            return ValueListenableBuilder<String>(
              valueListenable: ChordLevelPref.instance,
              builder: (context, _, __) {
                // Simplified once per track/level change (not per position
                // tick); slots, indexAt sync and beat dots all read it.
                final track = simplifyTrack(raw, ChordLevelPref.instance.level);
                return ValueListenableBuilder<MidiPlayback?>(
                  valueListenable: MidiPlayer.instance.current,
                  builder: (context, cur, _) => ValueListenableBuilder<int>(
                    valueListenable: MidiPlayer.instance.transpose,
                    builder: (context, semis, _) =>
                        ValueListenableBuilder<Duration>(
                      valueListenable: MidiPlayer.instance.position,
                      builder: (context, pos, _) {
                        final loaded = MidiPlayer.isCurrent(cur, widget.hymn);
                        final at =
                            loaded ? track.indexAt(pos.inMilliseconds) : 0;
                        final index = at < 0 ? 0 : at;
                        return Pressable(
                          onTap: () => _showChordSheet(t),
                          pressedScale: 0.98,
                          builder: (context, pressed) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              height: 36,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) {
                                  // Incoming slides in from the right; the
                                  // outgoing child (reversed animation)
                                  // slides out to the left — the row reads
                                  // as sliding left on each chord hit.
                                  final incoming =
                                      child.key == ValueKey<int>(index);
                                  final slide = Tween<Offset>(
                                    begin: Offset(incoming ? 0.35 : -0.35, 0),
                                    end: Offset.zero,
                                  );
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: animation.drive(slide),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Row(
                                  key: ValueKey<int>(index),
                                  children: [
                                    for (var slot = 0; slot < 3; slot++)
                                      Expanded(
                                        child: _chordSlot(
                                            t,
                                            track,
                                            index + slot,
                                            slot,
                                            semis,
                                            loaded ? pos.inMilliseconds : -1),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// One fixed-width strip slot: 0 = current chord (accent pill), 1 and 2 =
  /// the upcoming chords, visibly receding. Empty past the end of the track.
  /// A chord held across several beats shows one dot per repeat; on the
  /// current chord each dot lights as its beat strikes ([positionMs] is -1
  /// when this hymn is not the one loaded).
  Widget _chordSlot(HymnalTokens t, ChordTrack track, int i, int slot,
      int semis, int positionMs) {
    if (i >= track.chords.length) return const SizedBox.shrink();
    final e = track.chords[i];
    final label = chordLabel(e.rootPc, e.quality, track.key, semis);
    final repeats = e.beatMs.length - 1;
    if (slot == 0) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
                if (repeats > 0) const SizedBox(width: 6),
                for (var k = 1; k <= repeats; k++) ...[
                  if (k > 1) const SizedBox(width: 3),
                  _beatDot(
                    // Lit once its beat has struck.
                    positionMs >= 0 && positionMs >= e.beatMs[k]
                        ? t.accent
                        : t.accent.withValues(alpha: 0.25),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    final tone = slot == 1 ? t.muted : t.faint;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: slot == 1 ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
            if (repeats > 0) const SizedBox(width: 5),
            for (var k = 1; k <= repeats; k++) ...[
              if (k > 1) const SizedBox(width: 3),
              _beatDot(tone.withValues(alpha: 0.35)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _beatDot(Color color) => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  /// Chord chart sheet (same visual pattern as the speed sheet, but taller
  /// and scrollable): the whole tune as a measure grid, four bars per row,
  /// with the playing measure highlighted live. Relabels on transpose.
  void _showChordSheet(HymnalTokens t) {
    AppAnalytics.instance.event('chord_chart_open');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ValueListenableBuilder<ChordTrack?>(
            valueListenable: MidiPlayer.instance.chordTrack,
            builder: (context, raw, _) {
              if (raw == null) return const SizedBox.shrink();
              return ValueListenableBuilder<String>(
                valueListenable: ChordLevelPref.instance,
                builder: (context, _, __) {
                  // The chart reads the same simplified track as the strip,
                  // so bars, labels and beat dots track the level live.
                  final track =
                      simplifyTrack(raw, ChordLevelPref.instance.level);
                  return ValueListenableBuilder<int>(
                    valueListenable: MidiPlayer.instance.transpose,
                    builder: (context, semis, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SectionLabel(context.appText.chords.toUpperCase()),
                            const Spacer(),
                            Text(
                              _chordMeta(track, semis),
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 12,
                                color: t.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Flexible(child: _measureGrid(t, track, semis)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Sheet meta line: 'Key of G · 4/4' (key part omitted when the file has
  /// no key signature); the key relabels with the transposition.
  String _chordMeta(ChordTrack track, int semis) {
    final key = track.key;
    final meter = track.meterLabel;
    return key == null
        ? meter
        : '${context.appText.keyOf(transposedKeyLabel(key, semis))} · $meter';
  }

  /// Scrollable measure grid: one cell per measure, four per row, barline on
  /// the left edge of each cell. Each cell is a beat grid — every chord beat
  /// onset in the measure's window, sorted by time — so its symbols always
  /// add up to the bar's beats. The measure under the playhead is highlighted
  /// while this hymn is loaded and pulses beat by beat.
  Widget _measureGrid(HymnalTokens t, ChordTrack track, int semis) {
    final measures =
        List.generate(track.measureStartMs.length, (_) => <_MeasureBeat>[]);
    if (measures.isNotEmpty) {
      for (final e in track.chords) {
        for (final b in e.beatMs) {
          final m = track.measureAt(b);
          measures[m < 0 ? 0 : m]
              .add((ms: b, onset: b == e.beatMs.first, chord: e));
        }
      }
      for (final beats in measures) {
        beats.sort((a, b) => a.ms - b.ms);
      }
    }
    return ValueListenableBuilder<MidiPlayback?>(
      valueListenable: MidiPlayer.instance.current,
      builder: (context, cur, _) => ValueListenableBuilder<Duration>(
        valueListenable: MidiPlayer.instance.position,
        builder: (context, pos, _) {
          final loaded = MidiPlayer.isCurrent(cur, widget.hymn);
          final at = loaded ? track.measureAt(pos.inMilliseconds) : -1;
          return GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.2,
            ),
            itemCount: measures.length,
            itemBuilder: (context, i) => _measureCell(
                t, measures[i], track.key, semis,
                current: i == at, positionMs: loaded ? pos.inMilliseconds : -1),
          );
        },
      ),
    );
  }

  /// One measure cell: a symbol per beat — the chord label on its onset beat,
  /// a dot for every further beat it is held — with the left border as the
  /// barline. In the current measure, symbols light up in accent as their
  /// beats strike ([positionMs] is -1 when this hymn is not the one loaded).
  Widget _measureCell(
    HymnalTokens t,
    List<_MeasureBeat> beats,
    MidiKey? key,
    int semis, {
    required bool current,
    required int positionMs,
  }) {
    Color tone(int ms, {required bool dot}) {
      if (current) {
        return ms <= positionMs ? t.accent : t.accent.withValues(alpha: 0.35);
      }
      return dot ? t.ink.withValues(alpha: 0.35) : t.ink;
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: current ? t.tint : Colors.transparent,
        border: Border(left: BorderSide(color: t.line2)),
      ),
      child: beats.isEmpty
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var k = 0; k < beats.length; k++) ...[
                    if (k > 0) const SizedBox(width: 5),
                    // A chord carried over the barline is spelled out when it
                    // is the bar's first symbol; dots are only ever holds
                    // WITHIN the bar.
                    if (k == 0 || beats[k].onset)
                      Text(
                        chordLabel(beats[k].chord.rootPc,
                            beats[k].chord.quality, key, semis),
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: tone(beats[k].ms, dot: false),
                        ),
                      )
                    else
                      _beatDot(tone(beats[k].ms, dot: true)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _seekButton(HymnalTokens t, {required bool forward}) {
    final canPlay = MidiPlayer.hasMusic(widget.hymn);
    return Opacity(
      opacity: canPlay ? 1.0 : 0.45,
      child: Pressable(
        onTap: canPlay
            ? () => MidiPlayer.instance
                .seekBy(Duration(seconds: forward ? 10 : -10))
            : null,
        pressedScale: 0.92,
        builder: (context, pressed) => Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
          child: HymnalIcons.seek10(t.ink, forward: forward, size: 20),
        ),
      ),
    );
  }

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static String _speedLabel(double s) =>
      '${s == s.roundToDouble() ? s.round() : s}×';

  /// Current-speed pill (mockup's "1.0×" placeholder, now live): tap opens
  /// the speed picker sheet.
  Widget _speedPill(HymnalTokens t) {
    final canPlay = MidiPlayer.hasMusic(widget.hymn);
    return Opacity(
      opacity: canPlay ? 1.0 : 0.45,
      child: ValueListenableBuilder<double>(
        valueListenable: MidiPlayer.instance.speed,
        builder: (context, speed, _) => Pressable(
          onTap: canPlay ? () => _showSpeedSheet(t) : null,
          pressedScale: 0.95,
          builder: (context, pressed) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: speed == 1.0 ? t.surface2 : t.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _speedLabel(speed),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: speed == 1.0 ? t.muted : t.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedSheet(HymnalTokens t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.appText.playbackSpeed.toUpperCase(),
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: trackingEm(0.14, 11),
                  color: t.muted,
                ),
              ),
              const SizedBox(height: 14),
              // Eight speeds flow as two rows of four; the slow half is for
              // learning parts, the fast half for review.
              for (final row in [
                _speeds.sublist(0, 4),
                _speeds.sublist(4)
              ]) ...[
                Row(
                  children: [
                    for (final (i, s) in row.indexed) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: _speedChip(t, s, sheetContext),
                      ),
                    ],
                  ],
                ),
                if (row.first == _speeds.first) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedChip(HymnalTokens t, double s, BuildContext sheetContext) {
    final selected = MidiPlayer.instance.speed.value == s;
    return Pressable(
      onTap: () {
        MidiPlayer.instance.setSpeed(s);
        Navigator.pop(sheetContext);
      },
      pressedScale: 0.95,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.accent : Colors.transparent,
          border: Border.all(color: selected ? t.accent : t.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _speedLabel(s),
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? t.onAccent : t.muted,
          ),
        ),
      ),
    );
  }

  /// Current-key pill: shows the (possibly transposed) key of this hymn's
  /// tune; tap opens the transpose sheet. Dimmed and inert on Old-Hymnal
  /// pages, like the play button.
  Widget _keyPill(HymnalTokens t) {
    final canPlay = MidiPlayer.hasMidi(widget.hymn);
    return Opacity(
      opacity: canPlay ? 1.0 : 0.45,
      child: ValueListenableBuilder<MidiKey?>(
        valueListenable: MidiPlayer.instance.originalKey,
        builder: (context, key, _) => ValueListenableBuilder<int>(
          valueListenable: MidiPlayer.instance.transpose,
          builder: (context, semis, _) {
            final shifted = semis != 0;
            final label = key != null
                ? context.appText.keyValue(transposedKeyLabel(key, semis))
                : shifted
                    ? '${semis > 0 ? '+' : ''}$semis st'
                    : context.appText.key;
            return Pressable(
              onTap: canPlay ? () => _showKeySheet(t) : null,
              pressedScale: 0.95,
              builder: (context, pressed) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shifted ? t.tint : t.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: shifted ? t.accent : t.muted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Transpose sheet: −/+ steppers around the current key, live (-6..+6,
  /// each tap re-renders playback immediately; the sheet stays open and
  /// rebuilds off the transpose notifier).
  void _showKeySheet(HymnalTokens t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: MidiPlayer.instance.transpose,
            builder: (context, semis, _) {
              final key = MidiPlayer.instance.originalKey.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.appText.key.toUpperCase(),
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: trackingEm(0.14, 11),
                          color: t.muted,
                        ),
                      ),
                      const Spacer(),
                      if (semis != 0)
                        Pressable(
                          onTap: () => MidiPlayer.instance.setTranspose(0),
                          pressedScale: 0.95,
                          builder: (context, pressed) => Text(
                            context.appText.reset,
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: t.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _keyStepper(t, semis: semis, delta: -1),
                      Expanded(child: _keyReadout(t, key, semis)),
                      _keyStepper(t, semis: semis, delta: 1),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Center of the transpose sheet: big current key, shift indicator when
  /// transposed, and the written key underneath.
  Widget _keyReadout(HymnalTokens t, MidiKey? key, int semis) {
    final big = key != null
        ? transposedKeyLabel(key, semis)
        : semis != 0
            ? '${semis > 0 ? '+' : ''}$semis st'
            : '±0';
    return Column(
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: big,
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: t.accent,
              ),
            ),
            if (key != null && semis != 0)
              TextSpan(
                text: '  (${semis > 0 ? '+' : ''}$semis)',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
          ]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          context.appText.originalKey(key?.label ?? '—'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 11.5,
            color: t.muted,
          ),
        ),
      ],
    );
  }

  /// −/+ stepper (42px surface2 circle); dimmed and inert at the -6/+6 ends.
  Widget _keyStepper(HymnalTokens t, {required int semis, required int delta}) {
    final target = semis + delta;
    final enabled = target >= -6 && target <= 6;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Pressable(
        onTap: enabled ? () => MidiPlayer.instance.setTranspose(target) : null,
        pressedScale: 0.92,
        builder: (context, pressed) => Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
          child: Text(
            delta < 0 ? '−' : '+',
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: t.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(HymnalTokens t,
      {Key? key, required VoidCallback onTap, required Widget icon}) {
    return Pressable(
      key: key,
      onTap: onTap,
      pressedScale: 0.92,
      builder: (context, pressed) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
        child: icon,
      ),
    );
  }

  Future<void> _toggleMusic() async {
    try {
      await MidiPlayer.instance.toggle(widget.hymn);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.appText.musicLoadError),
      ));
    }
  }

  Widget _playButton(HymnalTokens t) {
    // Both bundled editions have MIDI; malformed/out-of-range records remain
    // dimmed and inert.
    final canPlay = MidiPlayer.hasMusic(widget.hymn);
    return ValueListenableBuilder<MidiPlayback?>(
      valueListenable: MidiPlayer.instance.current,
      builder: (context, cur, _) {
        final isPlaying = canPlay &&
            MidiPlayer.isCurrent(cur, widget.hymn) &&
            cur?.paused == false;
        return Semantics(
          button: true,
          enabled: canPlay,
          label:
              isPlaying ? context.appText.pauseHymn : context.appText.playHymn,
          child: Opacity(
            opacity: canPlay ? 1.0 : 0.45,
            child: Pressable(
              key: const ValueKey('hymn-play-pause'),
              onTap: canPlay ? _toggleMusic : null,
              pressedScale: 0.92,
              builder: (context, pressed) => Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent,
                  shape: BoxShape.circle,
                  boxShadow: t.playShadow,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: MidiPlayer.instance.loading,
                  builder: (context, loading, _) =>
                      loading && MidiPlayer.isCurrent(cur, widget.hymn)
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: t.onAccent))
                          : isPlaying
                              ? HymnalIcons.pauseBars(t.onAccent)
                              : HymnalIcons.playTriangle(t.onAccent),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One beat slot of a chord-chart measure cell: the beat's media-time ms,
/// whether it is the chord's onset beat (label) or a hold beat (dot), and the
/// chord sounding on it.
typedef _MeasureBeat = ({int ms, bool onset, ChordEvent chord});
