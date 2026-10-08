# Interface translation workflow

Interface language and hymnal language are separate preferences. Selecting a
book must never change the interface language or translate the book's source
lyrics. The initial interface remains English, preserving existing behavior.

The foundation supports English (`en`), Spanish (`es`), Portuguese (`pt`), and
Russian (`ru`). `AppLanguage` saves only `appInterfaceLanguage`; it does not alter
book selection, favorites, history, or music settings. Unknown stored language
values fall back to English without overwriting the saved value.

## Current rollout status

The catalogs and Flutter localization delegates are in place. Shared screens
still need to consume the messages. **Do not expose the language selector until
the main navigation, keypad, search, favorites, reader, and settings flows have
complete coverage and have been checked in both designs.** This milestone does
not claim that the app interface is fully translated. The initial 59-message
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
