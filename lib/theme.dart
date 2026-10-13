import 'package:flutter/material.dart';

/// Design tokens from the redesign handoff
/// (assets/design_handoff_hymnal_redesign/README.md). One instance per
/// brightness; access via `context.tokens`.
class HymnalTokens extends ThemeExtension<HymnalTokens> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;
  final Color line2;
  final Color accent;
  final Color accentHi;
  final Color deep;
  final Color tint;
  final Color gold;
  final Color goldBg;
  final Color key;
  final Color onAccent;
  final Color barBg;
  final Color markTile;
  final Color markPipe;
  final Color markPipe2;
  final bool isDark;
  final bool isClassic;

  const HymnalTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.line2,
    required this.accent,
    required this.accentHi,
    required this.deep,
    required this.tint,
    required this.gold,
    required this.goldBg,
    required this.key,
    required this.onAccent,
    required this.barBg,
    required this.markTile,
    required this.markPipe,
    required this.markPipe2,
    required this.isDark,
    this.isClassic = false,
  });

  /// Original high-contrast, monochrome layout, with an accessible dark
  /// counterpart. Keep the same semantic tokens for shared playback tools.
  static HymnalTokens classic(bool dark) {
    final source = dark ? HymnalTokens.dark : HymnalTokens.light;
    final ink = dark ? Colors.white : Colors.black;
    final bg = dark ? const Color(0xFF121212) : Colors.white;
    return HymnalTokens(
      isDark: dark,
      isClassic: true,
      bg: bg,
      surface: dark ? const Color(0xFF202020) : Colors.white,
      surface2: dark ? const Color(0xFF303030) : const Color(0xFFE0E0E0),
      ink: ink,
      muted: dark ? Colors.white70 : Colors.black87,
      faint: dark ? Colors.white60 : Colors.black54,
      line: dark ? Colors.white54 : Colors.black54,
      line2: dark ? Colors.white24 : Colors.black12,
      accent: dark ? source.accent : const Color(0xFF0B6138),
      accentHi: source.accentHi,
      deep: source.deep,
      tint: source.tint,
      gold: source.gold,
      goldBg: source.goldBg,
      key: bg,
      onAccent: source.onAccent,
      barBg: bg,
      markTile: source.markTile,
      markPipe: source.markPipe,
      markPipe2: source.markPipe2,
    );
  }

  static const light = HymnalTokens(
    bg: Color(0xFFFAFAF7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F1EE),
    ink: Color(0xFF131714),
    muted: Color(0xFF6E7873),
    faint: Color(0xFF9AA39D),
    line: Color(0xFFE5E8E4),
    line2: Color(0xFFEEF0EC),
    accent: Color(0xFF176A50),
    accentHi: Color(0xFF1E8A63),
    deep: Color(0xFF0D3F30),
    tint: Color(0xFFEAF1EC),
    gold: Color(0xFFA87E2F),
    goldBg: Color(0x1AA87E2F), // rgba(168,126,47,0.1)
    key: Color(0xFFFFFFFF),
    onAccent: Color(0xFFFFFFFF),
    barBg: Color(0xEBFFFFFF), // rgba(255,255,255,0.92)
    markTile: Color(0xFF0D3F30),
    markPipe: Color(0xFFEAF1EC),
    markPipe2: Color(0xFF7FD6B4),
    isDark: false,
  );

  static const dark = HymnalTokens(
    bg: Color(0xFF0C110E),
    surface: Color(0x0BFFFFFF), // rgba(255,255,255,0.045)
    surface2: Color(0x0AFFFFFF), // rgba(255,255,255,0.04)
    ink: Color(0xFFF2F4F0),
    muted: Color(0xFF93A099),
    faint: Color(0xFF5D6862),
    line: Color(0x17FFFFFF), // rgba(255,255,255,0.09)
    line2: Color(0x12FFFFFF), // rgba(255,255,255,0.07)
    accent: Color(0xFF3ECF95),
    accentHi: Color(0xFF5FDCAA),
    deep: Color(0xFF0D3F30),
    tint: Color(0x1F3ECF95), // rgba(62,207,149,0.12)
    gold: Color(0xFFD8C289),
    goldBg: Color(0x1AD8C289), // rgba(216,194,137,0.1)
    key: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
    onAccent: Color(0xFF0C110E),
    barBg: Color(0xE6171E1A), // rgba(23,30,26,0.9)
    markTile: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    markPipe: Color(0xFFDFE6E0),
    markPipe2: Color(0xFF3ECF95),
    isDark: true,
  );

  /// Card/key shadow: light `0 1px 2px rgba(16,21,15,0.04)`, none in dark.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x0A10150F), offset: Offset(0, 1), blurRadius: 2),
        ];

  /// Floating player bar: `0 8px 24px rgba(16,21,15,0.1)`, light only.
  List<BoxShadow> get barShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x1A10150F), offset: Offset(0, 8), blurRadius: 24),
        ];

  /// Primary CTA button: `0 4px 14px rgba(23,106,80,0.3)`, light only.
  List<BoxShadow> get ctaShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x4D176A50), offset: Offset(0, 4), blurRadius: 14),
        ];

  /// Accent play button: `0 4px 12px rgba(23,106,80,0.35)`, light only.
  List<BoxShadow> get playShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x59176A50), offset: Offset(0, 4), blurRadius: 12),
        ];

  /// Slider thumb: `0 2px 6px rgba(16,21,15,0.18)`, light only.
  List<BoxShadow> get thumbShadow => isDark
      ? const []
      : const [
          BoxShadow(
              color: Color(0x2E10150F), offset: Offset(0, 2), blurRadius: 6),
        ];

  @override
  HymnalTokens copyWith() => this;

  @override
  HymnalTokens lerp(ThemeExtension<HymnalTokens>? other, double t) =>
      t < 0.5 ? this : (other as HymnalTokens? ?? this);
}

/// Font family names (bundled in assets/fonts, declared in pubspec.yaml).
const kSans = 'InstrumentSans';
const kSerif = 'Literata';

/// CSS letter-spacing `em` → Flutter logical px for the given font size.
double trackingEm(double em, double fontSize) => em * fontSize;

/// Opaque raised surface for sheets, menus and dialogs. The dark tokens'
/// cards are translucent, which reads as muddy when stacked over content.
Color raisedSurface(HymnalTokens t) =>
    t.isDark ? (t.isClassic ? const Color(0xFF202020) : const Color(0xFF171E1A)) : t.surface;

ThemeData buildHymnalTheme(HymnalTokens t, {bool classic = false}) {
  if (classic) t = HymnalTokens.classic(t.isDark);
  final base = t.isDark
      ? ThemeData.dark(useMaterial3: !classic)
      : ThemeData.light(useMaterial3: !classic);
  final textTheme = base.textTheme.apply(
    fontFamily: classic ? 'Roboto' : kSans,
    // Instrument Sans lacks Cyrillic; the bundled Literata face supplies it
    // offline in menus and labels as well as in the hymn lyrics.
    fontFamilyFallback: const ['Literata'],
    bodyColor: t.ink,
    displayColor: t.ink,
  );
  final themed = base.copyWith(
    scaffoldBackgroundColor: t.bg,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: t.accent,
      onPrimary: t.onAccent,
      secondary: t.accent,
      onSecondary: t.onAccent,
      surface: t.bg,
      onSurface: t.ink,
    ),
    textTheme: textTheme,
    extensions: [t],
  );
  // Classic deliberately keeps the original app's stock widgets.
  if (classic) return themed;

  final raised = raisedSurface(t);
  final sans = TextStyle(fontFamily: kSans, color: t.ink);
  const stadium = StadiumBorder();
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: t.line),
  );
  return themed.copyWith(
    colorScheme: themed.colorScheme.copyWith(
      primaryContainer: t.tint,
      onPrimaryContainer: t.accent,
      secondaryContainer: t.tint,
      onSecondaryContainer: t.accent,
      tertiary: t.gold,
      onSurfaceVariant: t.muted,
      outline: t.isDark ? t.faint : const Color(0xFFC9CFCA),
      outlineVariant: t.line,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: raised,
      surfaceContainerLow: raised,
      surfaceContainer: raised,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: t.isDark ? const Color(0xFF1C2721) : t.surface2,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: sans.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: t.ink),
      shape: Border(bottom: BorderSide(color: t.line2)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: raised,
      modalBackgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.isDark ? const Color(0xFF1C2721) : t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.line)),
      textStyle: sans.copyWith(fontSize: 14.5),
      labelTextStyle: WidgetStatePropertyAll(sans.copyWith(fontSize: 14.5)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: sans.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: sans.copyWith(fontSize: 14.5, color: t.muted, height: 1.35),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.isDark ? const Color(0xFF243029) : t.ink,
      contentTextStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 14,
          color: t.isDark ? t.ink : t.bg),
      actionTextColor: t.isDark ? t.accent : const Color(0xFF7FD6B4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
          borderSide: BorderSide(color: t.accent, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: TextStyle(fontFamily: kSans, color: t.muted),
      floatingLabelStyle: TextStyle(fontFamily: kSans, color: t.accent),
      hintStyle: TextStyle(fontFamily: kSans, color: t.faint),
      prefixIconColor: t.faint,
      suffixIconColor: t.faint,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: t.accent,
      disabledColor: t.surface2,
      checkmarkColor: t.onAccent,
      side: BorderSide(color: t.line),
      shape: stadium,
      showCheckmark: false,
      labelStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: t.muted),
      secondaryLabelStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: t.onAccent),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? t.onAccent : t.surface),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? t.accent : t.surface2),
      trackOutlineColor: WidgetStatePropertyAll(t.line),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? t.accent : Colors.transparent),
      checkColor: WidgetStatePropertyAll(t.onAccent),
      side: BorderSide(color: t.faint, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? t.accent : t.faint),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: t.accent,
      inactiveTrackColor: t.surface2,
      thumbColor: t.accent,
      overlayColor: t.tint,
      trackHeight: 4,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent, linearTrackColor: t.surface2),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        textStyle: const TextStyle(
            fontFamily: kSans, fontSize: 14.5, fontWeight: FontWeight.w600),
        shape: stadium,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 0,
        textStyle: const TextStyle(
            fontFamily: kSans, fontSize: 14.5, fontWeight: FontWeight.w600),
        shape: stadium,
        minimumSize: const Size(0, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        side: BorderSide(color: t.line),
        textStyle: const TextStyle(
            fontFamily: kSans, fontSize: 14.5, fontWeight: FontWeight.w600),
        shape: stadium,
        minimumSize: const Size(0, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.accent,
        textStyle: const TextStyle(
            fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.accent,
      foregroundColor: t.onAccent,
      elevation: 2,
      extendedTextStyle: const TextStyle(
          fontFamily: kSans, fontSize: 14.5, fontWeight: FontWeight.w600),
      shape: stadium,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.muted,
      textColor: t.ink,
      titleTextStyle:
          sans.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      subtitleTextStyle:
          TextStyle(fontFamily: kSans, fontSize: 12.5, color: t.muted),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: t.accent,
      collapsedIconColor: t.faint,
      textColor: t.ink,
      collapsedTextColor: t.ink,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    dividerTheme: DividerThemeData(color: t.line2, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: t.muted),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: t.isDark ? const Color(0xFF243029) : t.ink,
          borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(
          fontFamily: kSans, fontSize: 12, color: t.isDark ? t.ink : t.bg),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.accentHi,
      selectionColor: t.accent.withValues(alpha: 0.25),
      selectionHandleColor: t.accent,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: sans.copyWith(fontSize: 15),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
            t.isDark ? const Color(0xFF1C2721) : t.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: t.line))),
      ),
    ),
  );
}

extension HymnalTokensX on BuildContext {
  /// Falls back to the stock palette for a bare MaterialApp (previews and
  /// isolated widget tests) instead of failing to build.
  HymnalTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<HymnalTokens>() ??
        (theme.brightness == Brightness.dark
            ? HymnalTokens.dark
            : HymnalTokens.light);
  }
}
