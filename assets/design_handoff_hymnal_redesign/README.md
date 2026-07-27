# Handoff: Old & New SDA Hymnal — UI Redesign (v3)

## Overview
Complete visual redesign of the existing Flutter hymnal app (`sdahymnal`). Same features and information architecture (number keypad, search, settings, hymn reading, font size, about/donate/other-projects), rebuilt with a new design language: warm off-white/deep-charcoal surfaces, emerald accent used sparingly, gold for chorus markers, Literata serif for hymn content, Instrument Sans for UI. Adds: light/dark/system theme, recents chips, live keypad preview cards, and a hymn-page player bar placeholder for v-next audio features.

## About the Design Files
The files in `mockups/` are **design references created in HTML** — interactive prototypes showing intended look and behavior, not production code. The task is to **recreate these designs in the existing Flutter codebase** (`lib/ui/*.dart`), keeping its established patterns (SharedPreferences, models, HymnApi). Open `mockups/Numbers v2.dc.html` in a browser to explore; all screens are linked together and fully interactive, including the theme toggle in Settings.

## Fidelity
**High-fidelity.** Colors, typography, spacing, radii, and copy are final. Recreate pixel-faithfully. Exact values below; the mockups are the source of truth if anything is ambiguous.

## Existing code map

| Screen | Mockup | Flutter file to restyle |
|---|---|---|
| Numbers (home tab) | `Numbers v2.dc.html` | `lib/ui/buttons.dart` |
| Search tab | `Search v2.dc.html` | `lib/ui/hymnlist.dart` |
| Settings tab | `Settings v2.dc.html` | `lib/ui/settings.dart` |
| Hymn page | `Hymn Page v2.dc.html` | `lib/ui/hymnPage.dart` |
| Font Size | `Font Size v2.dc.html` | `lib/ui/fontsize.dart` |
| About Us | `About v2.dc.html` | `lib/ui/about.dart` |
| Donate | `Donate v2.dc.html` | `lib/ui/donate.dart` |
| Other Projects | `Other Projects v2.dc.html` | `lib/ui/sp.dart` |
| Tab scaffold + theme | (headers/nav in every mockup) | `lib/ui/tabs.dart`, `lib/main.dart` |

`models/hymn.dart` and `services/api.dart` need no changes. `hymns.json` is unchanged.

## Design Tokens

Define once (e.g. `lib/theme.dart`) and consume everywhere. Token → light / dark:

| Token | Light | Dark | Use |
|---|---|---|---|
| bg | `#FAFAF7` | `#0C110E` | Scaffold background |
| surface | `#FFFFFF` | `rgba(255,255,255,0.045)` | Cards, keys, list rows |
| surface2 | `#F0F1EE` | `rgba(255,255,255,0.04)` | Segmented track, utility keys, pressed rows |
| ink | `#131714` | `#F2F4F0` | Primary text |
| muted | `#6E7873` | `#93A099` | Secondary text, section labels |
| faint | `#9AA39D` | `#5D6862` | Tertiary text, inactive nav, placeholders |
| line | `#E5E8E4` | `rgba(255,255,255,0.09)` | Card/key borders |
| line2 | `#EEF0EC` | `rgba(255,255,255,0.07)` | Row dividers, header hairline |
| accent | `#176A50` | `#3ECF95` | Brand emerald: active nav, links, primary buttons, verse numbers |
| accentHi | `#1E8A63` | `#5FDCAA` | Hover/caret |
| deep | `#0D3F30` | `#0D3F30` | Logo tile (light) |
| tint | `#EAF1EC` | `rgba(62,207,149,0.12)` | Accent chip/badge background |
| gold | `#A87E2F` | `#D8C289` | CHORUS label |
| goldBg | `rgba(168,126,47,0.1)` | `rgba(216,194,137,0.1)` | (reserved) gold chip bg |
| key | `#FFFFFF` | `rgba(255,255,255,0.05)` | Keypad digit keys |
| onAccent | `#FFFFFF` | `#0C110E` | Text/icons on accent fills |
| barBg | `rgba(255,255,255,0.92)` | `rgba(23,30,26,0.9)` | Hymn-page floating bar (blurred) |

Shadows — light mode only (none in dark):
- Card/key: `0 1px 2px rgba(16,21,15,0.04)`
- Floating player bar: `0 8px 24px rgba(16,21,15,0.1)`
- Primary CTA button: `0 4px 14px rgba(23,106,80,0.3)`
- Accent play button: `0 4px 12px rgba(23,106,80,0.35)`

Dark mode extra: subtle radial glow behind the top of the Numbers screen — `radial-gradient(560px 300px at 50% -90px, rgba(30,138,99,0.18), transparent 70%)`.

Radii: 999 (pills/chips/badges), 16 (settings cards), 14 (keys, preview cards, search field, CTA buttons), 12 (icon buttons, segmented control track 12 / thumb 9), 20 (photo cards), 18 (player bar), 7 (logo tile at 26px).

## Typography
- **UI font: Instrument Sans** (Google Fonts) — weights 400/500/600/700.
- **Content serif: Literata** (Google Fonts, variable; italic used) — hymn lyrics, hymn titles, display number, "Old & New" in wordmark, "Aa" glyphs.
- Use the `google_fonts` package: `GoogleFonts.instrumentSans()`, `GoogleFonts.literata()`.

Scale (px ≈ logical px):
- Display hymn number (Numbers): Literata 600, ~46–62 (clamps with viewport height), letter-spacing 0.02em, with a 2px-wide blinking caret bar in accentHi
- Screen title (sub-pages): Instrument Sans 600, 16.5
- Hymn page header: crumb 10/600, letter-spacing 0.14em, muted; number Literata 700 16.5 in accent; title Literata 600 16.5, single line, ellipsized
- Hymn body: Literata, user font size (16–30, default 18), line-height 1.7
- Verse numbers inside body: Instrument Sans 700 at 0.68em of body size, letter-spacing 0.14em, accent color
- CHORUS label: Instrument Sans 700 at 0.62em, letter-spacing 0.14em, gold, not italic (chorus body stays Literata italic)
- Section headers (settings/labels like APPEARANCE, HYMN NUMBER): 11/600, letter-spacing 0.14em, muted, uppercase
- List row: number Literata 600 15.5 accent (right-aligned, min-width 34); title Literata 500 16
- Badges (NEW/OLD): 9–10/700, letter-spacing 0.1em; NEW = accent on tint, OLD = muted on surface2
- Nav labels: 10.5, 600 active (accent) / 500 inactive (faint)
- Keypad digits: Instrument Sans 600, 23
- Body/settings rows: 15/500 titles, 12.5 muted descriptions

## Brand / Logo
New logo = organ-pipe monogram + wordmark. Files in `flutter_assets/`:
- `logo-mark.svg` — light mode (deep `#0D3F30` rounded tile, two `#EAF1EC` pipes, third pipe `#7FD6B4`)
- `logo-mark-dark.svg` — dark mode (tile `rgba(255,255,255,0.08)`, pipes `#DFE6E0`, accent pipe `#3ECF95`)

Wordmark is text, not vector: "Old & New" in Literata italic 500 accent + "SDA Hymnal" in Instrument Sans 700 ink, 15.5px, 9px gap after the 26×26 mark. Replaces the old giant `logo.svg` AppBar. Header bar: 52px tall, 24px side padding, no border, sits on bg.

## Screens / Views

### 1. Numbers (home tab) — `buttons.dart`
Column, top to bottom:
1. **Brand header** (52px, as above).
2. **Display zone** (scrollable if short screen): "HYMN NUMBER" section label, then the typed number in huge Literata with blinking caret. Empty state shows only caret.
3. **Recents chips** (only if recents exist): "Recent" in 11px muted + up to 3 pill chips (12/600, surface bg, line border, radius 999) with hymn numbers; tap opens that hymn.
4. **Preview cards** (min-height 112 zone, 8px gap): when a number is typed, two tappable cards (surface, line border, radius 14, padding 12×16): NEW badge (accent/tint pill) + hymn title in Literata 16.5 + chevron; OLD badge (muted/surface2 pill) + title + chevron. If number > 695, NEW card shows "Not in the New Hymnal" in faint italic, chevron hidden, not tappable. When empty: centered hint "Type a hymn number to preview it here / New Hymnal 1–695 · Old Hymnal 1–703" (13px faint / 11.5px).
5. **Keypad** (pinned to bottom): 3-column grid, 9px gaps, 20px side padding. Keys: height 44–56 (flex with viewport), radius 14, key bg, line border, digit 23/600. Bottom row: clear (✕ icon), 0, backspace icon — utility keys use surface2 bg. Pressed: scale 0.95 + tint bg.
6. **Bottom nav** (76px + safe area): 3 items — Numbers (dot-grid icon), Search (magnifier), Settings (sliders). Active = accent icon + 10.5/600 label; inactive = faint. Top hairline `line`.

Behavior (matches current app, plus): typing caps at 3 digits and ≤703; preview titles update live (replaces the old NEW»/OLD» buttons + text lines — the cards ARE the buttons). Opening a hymn records it in recents (last 6 kept, 3 shown). Keypad disables nothing visually except NEW card as described.

### 2. Search tab — `hymnlist.dart`
1. Brand header (same).
2. **Search field**: surface card, radius 14, line border, magnifier icon (faint), placeholder "Search by title, lyrics or number" (15.5, faint). Searches title OR body (punctuation-stripped) OR number — same logic as now.
3. **Filter chips row**: All / New Hymnal / Old Hymnal segmented as 3 pills (12.5/600, radius 999): selected = accent bg + onAccent text; unselected = transparent bg, line border, muted text. Right-aligned result count, 12px faint ("695 hymns" / "12 matches"). Replaces the black ALL/OLD/NEW cycling button.
4. **Result list** (scrolls): rows 13px vertical padding, 20px horizontal, hairline `line2` divider. Row = right-aligned Literata number (accent) · title (Literata 16, ellipsized) · NEW/OLD badge pill · chevron. Pressed row bg surface2. Use ListView.builder; cap-free.

### 3. Settings tab — `settings.dart`
Brand header, then grouped cards (margin 20 sides, surface, line border, radius 16), section labels above each (APPEARANCE / READING / MORE):
- **APPEARANCE**: segmented control in a card — track surface2 radius 12 padding 4; three equal segments Light / Dark / System (13/600); selected segment = surface bg, accent text, card shadow, radius 9.
- **READING**: "Font Size" row — "Aa" Literata glyph (muted) + label + current value ("18 pt", 13 muted) + chevron → Font Size screen.
- **MORE**: three rows with icon (20px, muted, 1.6 stroke outline), title 15/500, description 12.5 muted, chevron; hairline dividers: About Us ("Who made this app?"), Donate ("Support the development"), Our Other Projects ("Like this app? You will love our ministry!").
- Footer, centered: small logo mark, "Old & New SDA Hymnal" 12 muted, "Version 3.0" 11 faint.
Replace the `settings_ui` package with plain widgets. **New feature: theme setting** — persist `theme` = light|dark|system in SharedPreferences; System follows platform brightness.

### 4. Hymn page — `hymnPage.dart`
- **Header** (56px, hairline bottom `line2`): back chevron button (42×42, radius 12); centered 2-line stack: crumb "NEW HYMNAL"/"OLD HYMNAL" (10/600, 0.14em, muted) over [number in accent Literata 700] + [title, Literata 600 16.5, ellipsized]; right: "Aa" button (42×42, Literata 15, muted) → Font Size screen (replaces going through Settings only).
- **Body**: max-width 560 centered, padding 26 top / 24 sides / 150 bottom (clears floating bar). Lyrics rendered from the existing HTML body via flutter_html with Style overrides: base = Literata, user size, line-height 1.7, ink color. Transform verse markers: `<font color="#0B6138"><b>N</b></font>` → accent sans 700 small-caps-style number (0.68em, 0.14em tracking); `<font color="#CD9B1D">CHORUS:</font>` → gold sans 700 "CHORUS" (0.62em), chorus verse stays italic serif. (In Flutter: custom extension/replace on the HTML string before rendering, mapping those two font tags to styled spans — same regexes as the mockup's `styleBody()`.)
- **Floating player bar** (v-next template; ship it as static UI): pinned 16px from sides, 18px from bottom; barBg with blur (BackdropFilter), line border, radius 18, shadow; contents: prev circle button (38, surface2) · spacer · "Key · F" pill (11.5/600, accent on tint) · play button (44 circle, accent bg, onAccent triangle, accent shadow) · "1.0×" pill (muted on surface2) · spacer · next circle button. Prev/next ARE functional: previous/next hymn.
- **Gestures**: keep horizontal swipe = prev/next hymn (existing slide transition is fine); also keyboard arrows on desktop if trivial. Opening records recents (see below).
- Bounds: new ≤ 695, old ≤ 703, min 1 — same as now.

### 5. Font Size — `fontsize.dart`
- Sub-page header (56px): back chevron, centered title "Font Size".
- **Slider card** (margin 20, surface, radius 16, padding 18): row "Lyrics size" (13/600 muted) ↔ live value "18 pt" (Literata 600 17 accent); custom slider — 4px track (surface2), filled portion accent, thumb 26px white circle with line border + soft shadow; range 16–30 step 1; small "A" / big "A" Literata glyphs under the ends. **Restyle away all the red Material slider theming.**
- **PREVIEW** section label, then sample hymn (All Creatures verse 1 + chorus) rendered exactly like the hymn page at the chosen size, updating live.
- Persists to SharedPreferences `fontSize` (same key as today).

### 6. About Us — `about.dart`
Sub-page header "About Us". Photo card (`rohan.jpg`, radius 20, 330px tall, cover, focus ~20% from top). Name row: "Rohan A. Smith" Literata 600 23 + "APP DEVELOPER" accent pill badge. Bio paragraph in Literata 16/1.65 (copy in mockup). Info card (surface, radius 16, hairline dividers): Country → "Jamaica" + flag.png (24×12, radius 2); Twitter → @frazras link (accent, launches URL); Email → rohan@exterbox.com (accent, mailto).

### 7. Donate — `donate.dart`
Sub-page header "Donate". Image card (`donate.jpg`, radius 20, 190 cover). Headline "Every dollar is appreciated" Literata 600 24. Paragraph Literata 16/1.65 (copy in mockup). Bottom-pinned CTA: full-width 52px accent button, radius 14, "Donate" 16/600 onAccent, CTA shadow → existing donate URL; caption below "Opens a secure page in your browser" 12 faint.

### 8. Our Other Projects — `sp.dart`
Same pattern as Donate: white logo card (`sp.png` on #FFFFFF card even in dark mode, radius 20, padding 26, contain, max-height 170), title "SabbathPrograms.com" Literata 600 23, paragraph (copy in mockup), bottom CTA "Visit the website" → https://sabbathprograms.com/weekly, caption "sabbathprograms.com/weekly".

## Interactions & Behavior
- **Navigation**: keep 3 tabs, but the old AppBar+TabBar is replaced by the 52px brand header + a custom 76px bottom nav bar (Numbers | Search | Settings). Sub-pages push with the existing slide transition; back = header chevron (always navigates back to the tab, not browser-style history).
- **Press feedback**: keys/cards/chips scale to ~0.95–0.985 while pressed (e.g. AnimatedScale on tap-down); list rows highlight surface2. No Material ink ripple — keep it flat.
- **Caret**: display caret blinks (1.2s cycle, hard on/off at 55%).
- **Theme**: `theme` pref = light|dark|system, applied app-wide via ThemeMode + two ThemeData sets built from the token table. Segmented control switches instantly.
- **Recents**: store JSON list of `{n, v}` (number, version) in SharedPreferences key `hymnalRecents`, most recent first, deduped, capped at 6; shown as 3 chips on Numbers. Updated on every hymn open (keypad, search, swipe, recents chip).
- **Player bar**: visual template only except prev/next (functional). Play, "Key · F", "1.0×" are inert placeholders for upcoming audio features — do not wire.
- **Loading**: hymns.json loads on launch as today; screens render immediately (empty states shown above).

## State Management
Current setState/SharedPreferences approach is fine. State needed: typed number string; recents list; theme pref; fontSize pref (double 16–30, default 18); search query + filter (ALL/NEW/OLD); current hymn (+ its list for prev/next).

## Assets
- Keep: `hymns.json`, `rohan.jpg`, `donate.jpg`, `flag.png`, `sp.png`, `icon.png` (app icon unchanged for now).
- Replace `logo.svg` usage with `flutter_assets/logo-mark.svg` / `logo-mark-dark.svg` + text wordmark.
- `lettern.svg` / `lettero.svg` no longer used (list rows use text badges).
- Icons: all UI icons are simple 1.6px-stroke outlines (see mockup SVGs — magnifier, sliders, dot-grid, chevrons, person, heart, grid, backspace, ✕). Recreate with CustomPaint/flutter_svg or nearest-match icon font; avoid heavy filled Material icons.
- Fonts via `google_fonts` package (Instrument Sans, Literata incl. italic).

## Files
- `mockups/*.dc.html` — the 8 interactive screens (open `Numbers v2.dc.html` first; requires `mockups/support.js` and `mockups/assets/hymns.json`, keep folder together). Theme toggle in Settings affects all screens.
- `flutter_assets/logo-mark.svg`, `flutter_assets/logo-mark-dark.svg` — new logo files.
- Suggested prompt for Claude Code: *"Implement the redesign described in design_handoff_hymnal_redesign/README.md across lib/ui and lib/main.dart. Keep models, services, JSON loading, and SharedPreferences keys as-is. Work screen by screen: theme.dart tokens first, then tabs.dart shell, then each screen."*
