# Shared screen design

Every screen, in every language and both designs, is built from one small set
of components in `lib/ui/kit.dart` and the tokens in `lib/theme.dart`. New
features should reuse them instead of stock Material layouts, so the app reads
as one product whether the reader opened English, Spanish or a downloaded book.

## Choosing a hymnal

- The selected hymnal is a compact pill in the header of the Numbers and
  Search tabs (`BookPill`, `lib/ui/book_picker.dart`), showing the language
  code with a globe icon. It replaces the former full-width dropdown.
- Tapping it opens the hymnal picker sheet: each language by its native name
  with its book title, the current choice marked, and a last row,
  "More languages", that opens Hymnal downloads. On the Search tab the sheet
  also offers "All languages".
- English and Spanish pair their New and Old books under one choice
  (`HymnalBook`, `lib/models/hymnal_book.dart`); every other language offers
  its single book. Number pad, search, topics and the reader use the same
  screens for all of them.

## Components

| Component | Use |
|---|---|
| `HymnalPage` | Every pushed screen: back chevron, centered title, optional `HeaderAction`, optional pinned `bottom` action. |
| `HymnalCard`, `SettingsRow`, `SettingsSwitchRow`, `RowValue`, `RowIcon` | Grouped settings-style lists. Switches are the flat `MiniSwitch`; whole rows are tappable. |
| `SectionLabel` + `sectionPadding()` | Small-caps section headings above cards. |
| `HymnSearchField` | Rounded search field with clear action. |
| `FilterPill`, `SegmentedPills` | Edition, category and option choices (never stock chips or dropdowns). |
| `LinkAction` | Small accent text actions (A–Z, Topics, Readings, New category). |
| `HymnRow` | Hymn and reading lists: accent number, serif title, optional subtitle, badge, favorite heart, chevron. |
| `showHymnalSheet`, `SheetOption` | Floating rounded sheets for options and pickers. |
| `DownloadRow`, `PillAction`, `BusyAction` | Download management rows (hymnals, sheet music). |
| `EmptyHint` | Quiet empty or failure state with an optional action. |

`buildHymnalTheme` maps every Material component (chips, menus, sheets,
dialogs, inputs, switches, buttons, sliders, snack bars) to the hymnal palette,
so any remaining stock widget still matches. Classic keeps the original app's
stock widgets on purpose and only adopts the palette.

## Reader

- Imported books show verse numbers and refrain labels with the same accent
  and gold styling as the English books. When the source prints one refrain
  after the first verse, the reader repeats it after every verse so the hymn
  ends on it (`lyricReadingHtml`); search, sharing and export keep source order.
- The reader menu is one sheet (`lib/ui/hymn_options_sheet.dart`): quick
  actions (Sheet music, Video, Text size, Share) on top, switches (Music
  player, Chord tabs, Choir practice, Auto-scroll) below, then Report. Rows
  for media a hymn lacks are simply absent.
- Readings use the same header, text size and opt-in auto-scroll.

## Checking a change

Render the affected screens before calling work complete: both designs,
light and dark, a long native title, larger text, and a compact phone. The
widget tests cover behavior; screenshots catch crowding that tests do not.
