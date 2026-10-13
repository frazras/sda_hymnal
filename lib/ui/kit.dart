import 'package:flutter/material.dart';

import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

/// Shared building blocks so every screen, in every language, uses the same
/// header, cards, rows, pills and sheets. Colors come from [HymnalTokens], so
/// Classic picks up its own palette and square corners automatically.

// ---------------------------------------------------------------------------
// Sub-page scaffold
// ---------------------------------------------------------------------------

/// A pushed screen: the shared back-chevron header over [body].
class HymnalPage extends StatelessWidget {
  const HymnalPage({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.floatingActionButton,
    this.bottom,
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final Widget? floatingActionButton;

  /// Pinned below [body], above the safe area (e.g. a primary action bar).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: floatingActionButton,
      // A bottom bar keeps floating snack bars above the pinned actions.
      bottomNavigationBar:
          bottom == null ? null : SafeArea(top: false, child: bottom!),
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            SubPageHeader(title: title, trailing: trailing),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// A 42×42 header action matching the back chevron's hit area.
class HeaderAction extends StatelessWidget {
  const HeaderAction(
      {super.key, required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 21, color: onTap == null ? t.faint : t.ink),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards, rows and switches (Settings pattern)
// ---------------------------------------------------------------------------

EdgeInsets sectionPadding({bool first = false}) =>
    EdgeInsets.fromLTRB(24, first ? 18 : 22, 24, 8);

/// Grouped surface: 20px side margins, hairline border, soft shadow.
class HymnalCard extends StatelessWidget {
  const HymnalCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.isClassic ? 4 : 16),
        boxShadow: t.cardShadow,
      ),
      // Tiles and ink responses inside paint on this transparent material.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Leading glyph for settings rows: a muted 20px icon.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {super.key, this.color});
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 20, color: color ?? context.tokens.muted);
}

/// A tappable card row: leading glyph, title (+ subtitle), optional trailing
/// value and chevron. Pressed state highlights with surface2.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.divider = false,
    this.chevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.titleColor,
    required this.onTap,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool divider;
  final bool chevron;
  final EdgeInsets padding;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleText = Text(
      title,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: onTap == null ? t.faint : (titleColor ?? t.ink),
      ),
    );
    return Semantics(
      button: onTap != null,
      child: Pressable(
        onTap: onTap,
        pressedScale: 1.0,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: padding,
          decoration: BoxDecoration(
            color: pressed ? t.surface2 : Colors.transparent,
            border:
                divider ? Border(bottom: BorderSide(color: t.line2)) : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox(width: 22, child: Center(child: leading)),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: subtitle == null
                    ? titleText
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleText,
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 12.5,
                              height: 1.3,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
              if (chevron) ...[
                const SizedBox(width: 12),
                HymnalIcons.rowChevron(t.faint, size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Muted trailing value text for [SettingsRow].
class RowValue extends StatelessWidget {
  const RowValue(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
              fontFamily: kSans, fontSize: 13, color: context.tokens.muted),
        ),
      );
}

/// A settings row whose whole surface flips a switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.divider = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: SettingsRow(
          leading: leading,
          title: title,
          subtitle: subtitle,
          divider: divider,
          chevron: false,
          trailing: MiniSwitch(value: value, enabled: onChanged != null),
          onTap: onChanged == null ? null : () => onChanged!(!value),
        ),
      );
}

/// Flat 44×24 pill switch. Taps land on the enclosing row.
class MiniSwitch extends StatelessWidget {
  const MiniSwitch({super.key, required this.value, this.enabled = true});
  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? t.accent : t.surface2,
          borderRadius: BorderRadius.circular(999),
          border: value ? null : Border.all(color: t.line),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.ease,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? t.onAccent : (t.isDark ? t.muted : t.surface),
              shape: BoxShape.circle,
              boxShadow: t.thumbShadow,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pills and segmented choices
// ---------------------------------------------------------------------------

/// Filter chip: accent-filled when selected, hairline outline otherwise.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.onAccent : t.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? t.accent : Colors.transparent,
            border: Border.all(color: selected ? t.accent : t.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inset segmented control (Light / Dark / System pattern).
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(t.isClassic ? 4 : 12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: options[i].$1 == selected,
                button: true,
                child: Pressable(
                  key: ValueKey('segment-${options[i].$1}'),
                  onTap: onSelected == null
                      ? null
                      : () => onSelected!(options[i].$1),
                  pressedScale: 0.97,
                  builder: (context, pressed) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: options[i].$1 == selected
                          ? (t.isDark ? const Color(0xFF243029) : t.surface)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(t.isClassic ? 3 : 9),
                      boxShadow:
                          options[i].$1 == selected ? t.cardShadow : const [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      options[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: options[i].$1 == selected ? t.accent : t.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small accent text action with an icon (Topics, A–Z, Readings...).
class LinkAction extends StatelessWidget {
  const LinkAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = onTap == null ? t.faint : t.accent;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.96,
        builder: (context, pressed) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search field and hymn rows
// ---------------------------------------------------------------------------

/// Rounded search field with a magnifier and a clear action.
class HymnSearchField extends StatelessWidget {
  const HymnSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.margin = const EdgeInsets.fromLTRB(20, 10, 20, 0),
    this.clearTooltip,
    this.autofocus = false,
  });

  final bool autofocus;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final EdgeInsets margin;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: margin,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.isClassic ? 4 : 14),
        boxShadow: t.cardShadow,
      ),
      child: Row(
        children: [
          HymnalIcons.magnifier(t.faint, size: 18, stroke: 1.8),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: t.accentHi,
              style: TextStyle(fontFamily: kSans, fontSize: 15.5, color: t.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: TextStyle(
                    fontFamily: kSans, fontSize: 15.5, color: t.faint),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(height: 44)
                : IconButton(
                    tooltip: clearTooltip,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: HymnalIcons.clearX(t.faint, size: 16),
                  ),
          ),
        ],
      ),
    );
  }
}

/// List row shared by search, favorites, topics and history: accent number,
/// serif title, optional subtitle/badge, trailing chevron (or [trailing]).
class HymnRow extends StatelessWidget {
  const HymnRow({
    super.key,
    required this.number,
    required this.title,
    required this.onTap,
    this.textDirection,
    this.subtitle,
    this.badge,
    this.trailing,
    this.favorite = false,
  });

  final String number;
  final String title;
  final TextDirection? textDirection;
  final String? subtitle;
  final Widget? badge;
  final Widget? trailing;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 1.0,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: pressed ? t.surface2 : Colors.transparent,
            border: Border(bottom: BorderSide(color: t.line2)),
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                alignment: Alignment.centerRight,
                child: Text(
                  number,
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection: textDirection,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                        color: t.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 12, color: t.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 10), badge!],
              if (favorite)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: HymnalIcons.heart(t.accent, size: 13, filled: true),
                ),
              const SizedBox(width: 12),
              trailing ?? HymnalIcons.rowChevron(t.faint, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered, quiet empty or status message.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.title, this.message, this.action});
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.muted)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      height: 1.4,
                      color: t.faint)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheets
// ---------------------------------------------------------------------------

/// Shows a rounded floating sheet with an optional small-caps [title].
Future<T?> showHymnalSheet<T>(
  BuildContext context, {
  String? title,
  Widget? titleTrailing,
  required Widget Function(BuildContext sheetContext) builder,
  bool scrollable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      final content = builder(sheetContext);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82),
            decoration: BoxDecoration(
              color: raisedSurface(t),
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(t.isClassic ? 6 : 22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                    child: Row(
                      children: [
                        Expanded(child: SectionLabel(title.toUpperCase())),
                        if (titleTrailing != null) titleTrailing,
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 8),
                Flexible(
                  child: Material(
                    type: MaterialType.transparency,
                    child: scrollable
                        ? content
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: content),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// One selectable option inside a sheet; a dot marks the current choice.
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.trailing,
    this.divider = true,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final Widget? trailing;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 1.0,
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: pressed ? t.surface2 : Colors.transparent,
            border: divider ? Border(bottom: BorderSide(color: t.line2)) : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: onTap == null
                                ? t.faint
                                : selected
                                    ? t.accent
                                    : t.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 12.5,
                              height: 1.3,
                              color: t.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              if (selected) ...[
                const SizedBox(width: 10),
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: t.accent, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A short code tile (EN, ES...) used in the hymnal picker and badges.
class CodeTile extends StatelessWidget {
  const CodeTile(this.code, {super.key, this.selected = false});
  final String code;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 38,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? t.accent : t.tint,
        borderRadius: BorderRadius.circular(t.isClassic ? 3 : 9),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: selected ? t.onAccent : t.accent,
        ),
      ),
    );
  }
}

/// Compact accent pill for row actions such as Download or Update.
class PillAction extends StatelessWidget {
  const PillAction({super.key, required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: onTap == null ? t.surface2 : t.tint,
            borderRadius: BorderRadius.circular(t.isClassic ? 4 : 999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: onTap == null ? t.faint : t.accent),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: onTap == null ? t.faint : t.accent)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Row for a downloadable collection: code tile, name, details, action.
class DownloadRow extends StatelessWidget {
  const DownloadRow({
    super.key,
    required this.code,
    required this.title,
    required this.details,
    required this.trailing,
    this.active = false,
    this.progress,
    this.showProgress = false,
    this.divider = false,
  });

  final String code;
  final String title;
  final String details;
  final Widget trailing;
  final bool active;
  final double? progress;
  final bool showProgress;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: t.line2)) : null),
      child: Row(children: [
        CodeTile(code, selected: active),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.ink)),
            const SizedBox(height: 2),
            Text(details,
                style: TextStyle(
                    fontFamily: kSans, fontSize: 12, height: 1.3, color: t.muted)),
            if (showProgress)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: progress, minHeight: 3),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: trailing,
        ),
      ]),
    );
  }
}

/// Spinner with a cancel button, shown while a download runs.
class BusyAction extends StatelessWidget {
  const BusyAction({super.key, this.progress, this.onCancel, this.cancelTooltip});
  final double? progress;
  final VoidCallback? onCancel;
  final String? cancelTooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, value: progress),
      ),
      IconButton(
        tooltip: cancelTooltip,
        onPressed: onCancel,
        icon: Icon(Icons.close, size: 18, color: t.muted),
      ),
    ]);
  }
}
