# Interface translation workflow

Interface language and hymnal language are separate preferences. Selecting a
book must never change the interface language or translate the book's source
lyrics. The initial interface remains English, preserving existing behavior.

The foundation supports English (`en`), Spanish (`es`), Portuguese (`pt`), and
Russian (`ru`). `AppLanguage` saves only `appInterfaceLanguage`; it does not alter
book selection, favorites, history, or music settings. Unknown stored language
values fall back to English without overwriting the saved value.

## Current rollout status

The catalogs and Flutter localization delegates are in place. Navigation, main
reader menu, musical style sheet, top-level settings, and keypad discovery labels
now consume the messages. Search labels, result counts, topic controls, and empty states also consume
localized messages. Favorites, category dialogs, reorder controls, and protected-storage warnings
also consume translations. Several reader/settings child screens still need
coverage. **Do not expose the language selector until
the main navigation, keypad, search, favorites, reader, and settings flows have
complete coverage and have been checked in both designs.** This milestone does
not claim that the app interface is fully translated. The 519-message
catalogs are draft translations that also need fluent community review.

## Contributor steps

1. Add stable semantic keys to `lib/l10n/app_en.arb`. Keep hymn lyrics, hymn
   titles, edition names, stored IDs, analytics keys, and musical note names out
   of the interface catalogs.
2. Add matching translations to the `es`, `pt`, and `ru` catalogs. Include an
   English `@key` description when context could be ambiguous. Use Flutter ICU
   placeholders/plurals instead of concatenating translated fragments.
3. Run `python3 tool/validate_translations.py`, then `flutter gen-l10n`.
   Commit regenerated Dart files alongside ARB changes; do not hand-edit them.
4. Have a fluent reviewer check meaning, church/musical terminology, and natural
   phrasing. Record the reviewer's name, language, scope, and date in the PR.
   Generated translations alone are not a community review.
5. Run the language preference/delegate tests and check the affected screens at
   compact width and increased text scale, with light/dark Modern and Classic.
   Ensure switching languages preserves the selected book and current route.

Use `context.appText` for screen messages. Its English fallback keeps isolated
widget previews/tests working without application delegates. Production uses
Flutter's locale-aware delegates, including built-in Material/Cupertino labels.
Right-to-left locales are not yet advertised; enabling one requires layout and
script-font review as well as complete message coverage.

Compact regression checks exercise translated navigation and the musical style
sheet in all four locales, at 320×568 with 1.3 text scale and both design token
sets in light/dark mode. Navigation labels stay on one line and scale down only
when necessary. This does not certify coverage or layout of untranslated screens.

Search regression checks preserve title-first accent-insensitive ranking in all
four interface locales and both designs. Filters wrap on narrow screens; count
messages use ICU plurals and locale-aware number formatting. All-book search
actions are checked at 320×568 with 1.3 text scale and a 220px keyboard inset.
Book titles, edition identities, topic titles, and lyrics remain source content.

Favorites regression checks create, reject empty/duplicate names, and rename
categories in all four locales and both designs at compact width and 1.3 text
scale. Source names and native book references survive saving and reloading.
Stored model validation messages remain unchanged; the dialog maps known errors
to translated presentation messages.

Long storage warnings place the retry action beneath the message. The reorder
page scrolls warnings and instructions together with the hymn list, preserving
access to content on compact screens and with larger text.

Reader key/speed/chord labels, author/composer prefixes, story links, ending
label, font-size controls, and auto-scroll controls now use the catalogs. Source
names and musical note names stay unchanged. Font and auto-scroll controls are
checked across all four locales, both designs and both themes at compact width
with 1.3 text scale, including slider/reset/start behavior. Reader regression
checks retain playback, transposition, page turning, and choir controls.

Reading-history confirmation/empty states, score controls/loading messages,
video close tooltip, and story heading/publisher guidance now consume translated
messages. History clearing is checked in all four locales, designs, and themes
at compact width and larger text; it preserves favorites, category membership,
and selected book. Localized score controls turn real pages, zoom/reset, and
return to lyrics in both designs. Printed scores and story source text remain
unchanged.

The error-report form now translates labels, validation, privacy guidance,
submission status, failures, and success messages. Compact tests exercise failed
submission followed by retry in all four locales, both designs and both themes
with larger text. Source titles/descriptions and stable report IDs stay unchanged.
Tests inject a mock submitter and never send feedback to administrators.

Instrument customization now translates every offered General MIDI preset
(111 programs), 11 families, ensemble roles, and choir controls. The `gmProgramN`
keys use zero-based bank IDs; their labels are translated, never the IDs. The
`instrument_text.dart` adapter keeps mapping separate from the sound catalog.
Coverage checks compare all English labels with the catalog and require mapped
labels for every offered program in all four locales. Compact picker tests
select/reset a real preset and reload preferences while retaining Jazz melody
volume at 50%. Choir tests rename source tracks, mute/solo/reset by track ID, and
retain custom names. Ensemble tests preserve style IDs, solo state, and volume.
Instrument families open at the top of their own lists. Choir card actions wrap
when larger text needs more room. These remain draft translations awaiting fluent
review.

The About screen translates its biography and contact labels while retaining
contact addresses and destinations. Contact rows wrap at compact widths with
larger text. Tests cover all four locales, both designs and both themes; mocked
link launches verify destinations without opening external applications. Score
layout tests also verify decoded page images rather than only page controls.

Community statistics now localize period filters, report status, chart labels,
country names, and explanatory text. Dates, weekdays, and grouped counts follow
the interface locale; activity units use ICU plurals, including Russian forms.
Unknown country codes remain visible as supplied. Compact checks cover recovery
from a load failure, saved reports, period selection, charts, and country filters
in all four locales, both designs, and both themes with larger text. Public
report fields, source song titles, and analytics event IDs stay unchanged.

Service playlist controls, name validation, item counts, storage warnings, and
the item picker now use translations. Reader position labels translate around
the user's unchanged service name. Uninstalled entries keep their book/item
identities and remain navigable; their buttons share available width. Tests
cover create, repeat, reorder, reload, rename, cancel/confirm deletion, storage
protection, and unavailable-item navigation in all four locales, both designs,
and both themes at compact width with larger text. Favorites and melody volume
remain unchanged after editing or deleting a service.

The lyrics copy/share page now translates controls, verse/section menu labels,
and success/failure notices. Source chorus headings and the exported title,
book identity, and lyrics remain unchanged. Tests exercise complete and selected
verse copying, native share-sheet anchoring, share failure followed by copying,
and clipboard failure across all four locales, both designs, and both themes.
Platform calls are mocked; tests do not send lyrics externally. Unnumbered
section previews also retain their exact source text under translated labels.

Additional-reading search/filter controls, reader options, scripture prefixes,
auto-scroll states, and navigation now use translations. Category position
labels also translate consistently in hymn and reading readers while retaining
the source category name. Category chips grow with text size and scroll
horizontally. Reading search shares accent normalization with hymn search and
shows an explicit empty state. Compact checks cover search, category wraparound,
report subjects, auto-scroll start/pause, and service-order navigation in all
four locales, both designs, and both themes. Reading titles, scripture
references, segments, response emphasis, and report identifiers remain source
data. Existing reader/design regression checks also pass.

Topic/occasion browsing now translates its controls, count units, edition
filters, and reading status. Source topic titles, descriptions, aliases, and
hymn/reading assignments stay unchanged. Compact checks exercise all four
locales, both designs, and both themes, including reading navigation and source
references. Missing reading data shows loading/unavailable status rather than
a false zero. A deferred asset-load regression verifies loading, failure, and
successful retry against the real reading catalog; retries bypass cached failed
asset futures and make a fresh request.

Keypad empty states, reading shortcuts, invalid-book feedback, and utility
button labels now use translations in Modern and Classic. Modern clear/delete
buttons expose named accessibility actions. Compact checks cover number entry,
reading previews, clearing/deleting digits, and paired Spanish Old/New previews
across all four interface locales, both designs, and both themes. Native book
names and titles remain unchanged. Preview badges wrap within a bounded width
so long edition labels leave room for hymn titles. Tests advance fixed frames
because the keypad cursor intentionally keeps blinking.

The Other Projects page translates its heading, description, and website action.
Brand names and the website destination remain unchanged. Compact checks cover
all four locales, both designs, and both themes with increased text scale,
decode the actual logo, and verify the destination through a mocked launcher.
The additional-hymnal loading failure now uses a translated retry message;
its loading and retry behavior is unchanged.
