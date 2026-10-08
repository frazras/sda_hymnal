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
not claim that the app interface is fully translated. The 225-message
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
