# Product Roadmap

This roadmap lists planned ideas and release follow-ups for the Old and New SDA
Hymnal app. Checkboxes describe implementation status. The next-work sequence
below is recommended; it is not a promised release schedule.

All work must follow the [UX contract](docs/ux-contract.md): preserve the shared
number pad, pair related editions, keep reader controls coherent, and check
small-screen layouts before adding more features.

## Recommended Next Work

1. Check the remaining flows on physical phones: background audio with
   lock-screen controls, a hymnal download, the share sheet, A–Z browsing,
   and a VideoPsalm import.
2. Ask fluent reviewers to sign off the Spanish, Portuguese and Russian
   interface, and the lyrics of the new optional hymnals.
3. Submit the corrected Google Play Data safety answers, and decide the
   publication rights of the Scripture and special songbooks.
4. Keep the shared design as features grow: one kit, one picker, one reader
   options sheet, and no crowding on small phones. Add cross-language music
   only where it is verified. Custom songbook imports are outside the active
   roadmap.

The [1 October 2026 project audit](docs/multilingual-resource-audit.md) compares
five source projects and all 26 Rejnac language repositories with our code. It
includes counts, gaps, source links, migration details, and validation criteria.
Items below are plans, not claims that multilingual content is already installed.

## Hymnal Content

- [x] Add an offline, zoomable, multipage sheet-music viewer for English 1985
      (723 pages covering 695 numbers), accessible from the hymn menu in both
      designs. Preserve playback/category autoplay, show clear missing-score
      states, and provide page, zoom, fit, and return-to-lyrics controls.
      [Source/import details](docs/sheet-music.md).
- [x] Add Spanish 2009 (614 pages) and Russian 1997 (506 pages) score packs
      to the existing viewer. Russian #244 has no source score. Image scores retain their
      printed key rather than transposing with MIDI.
- [x] Add all 225 additional readings from the New Hymnal, with categories,
      Scripture references, printed responsive typography, keypad lookup,
      search, swiping, and reading-speed auto-scroll.
- [x] Add searchable hymn and Scripture-reading lists from the New Hymnal
      topical index, while retaining suggested lists for communion, funerals,
      morning and evening worship, Sabbath, and other occasions.

## Languages and Downloadable Hymnals

- [x] Introduce stable English book/item identities, a shared repository, and
      versioned favorites/category/recents storage. Preserve original saved data,
      order, memberships, lyrics, media, and settings; protect unreadable lists
      from overwrite. [Foundation details](docs/hymnal-catalog.md).
- [x] Add a persistent language and hymnal-edition selector backed by the shared
      catalog. Support offline number/text/topic browsing, reading, paging,
      credits, and mixed-book favorites in both designs. Preserve English
      readings/media and hide unavailable foreign music controls.
- [x] Extend deployed analytics/error-report schemas to native book identities.
      Native counters, translated titles, book-specific suppression, and statistics
      links are implemented. Deployed native and legacy public snapshots are
      verified; older clients retain English-compatible reports.
- [x] Import Spanish 2009 (614 hymns), Spanish 1962 (527), Portuguese 1996 (610),
      and Russian 1997 (385) from pinned GoGoShift sources, including their topic
      indexes. Keep existing English corrections and music mappings.
      [Source and validation details](docs/language-packs.md). Reader/selector
      integration remains the separate item above.
- [x] Build repeatable source importers and a content validation report for
      GoGoShift text, VideoPsalm JSON, and structured verse/refrain JSON. Track
      provenance and reviewed overrides; catch duplicate numbers, empty lyrics,
      numbering gaps, invalid references, and missing media before publishing.
- [x] Add French Hymnes et Louanges (520) and Swahili Nyimbo za Kristo (220)
      through the shared keypad/search/reader; retain unknown edition years and
      omit unavailable topics/media.
- [x] Expand to the remaining reviewed Rejnac collections.
      Validate edition/language labels and disclose partial coverage; resolve
      known empty entries and duplicate numbers instead of silently renumbering.
      All 19 collections are optional downloads: 13 complete and six explicitly
      partial after reconciliation against their VideoPsalm packages, with
      each missing number listed in its coverage note.
      [Collections and decisions](docs/language-packs.md#expanded-optional-text-collections).
- [x] Offer Tagalog and Cebuano as explicitly partial collections (237 records
      each in the audited source) and the optional Adventist Youth songbook.
      Preserve their source page numbering. Tagalog and Cebuano keep even
      pages 2–474 after six reviewed label corrections.
- [ ] Publish the Scripture-song and supplemental ("special") songbooks after
      a publication-rights review. Both contain songs under active copyright
      (for example "Thy Word", 1984), and their source repository has no
      license. They are prepared on the local `rights-review/scripture-special-songs`
      branch and are not published.
- [ ] Let users download, update, and remove optional language and score
      packs. Keep audio on demand with bounded caching; full-edition audio
      downloads are deferred to preserve device storage. Show size and coverage, verify checksums, activate updates atomically,
      preserve the last working version and saved favorites, and keep the current
      English books available offline. Settings text-pack download, cancellation,
      update, removal, and live book refresh are implemented, with a language
      search and an Open action after each download. All 23 optional text packs
      were downloaded through the app's own download code from the pinned
      GitHub commit and verified on 13 October 2026, after fixing rejection of
      GitHub's gzip-compressed responses. Score transport, atomic storage, viewer
      integration, catalog publication, and management controls are implemented;
      current score collections remain included. Additional optional score
      collections and physical download-flow review remain.
- [ ] Localize the app interface independently of the selected book, starting
      with Spanish, Portuguese, and Russian; add a reviewed community translation
      workflow. The independent preference, Flutter delegates, and initial four
      translation catalogs are staged. Navigation, reader menus, settings, keypad
      labels, search, and favorites controls now consume translations; child
      screens are covered and an App language setting is exposed. Review CSV export
      and staged import with stale-text, ICU, and generated-API checks are implemented.
      Right-to-left books render independently of the interface direction, and
      a terminology review of all Spanish, Portuguese and Russian messages is
      applied ([glossary](docs/translation-glossary.md)). A fluent community
      review of each language remains.
- [x] Improve multilingual search with Unicode normalization, accent-insensitive
      matching where appropriate, book filters, and localized refrain handling.
      Retain exact-number/title ranking and benchmark a large installed catalog.

## Music and Choir Features

- [ ] Expand verified cross-language tune mappings. Spanish New #303 now has
      three-verse NEW BRITAIN playback verified against English New #108 and its
      Spanish score. New #230 now has its own score-corrected two-verse 6/8
      arrangement in Eb; other pairs require individual musical/form verification.

- [x] Add Jazz with piano chords, walking acoustic bass, swung ride cymbal,
      and customizable ensemble instruments and mix.
- [x] Allow listeners to choose the instruments used for a musical style.
      Opt-in Settings controls save instruments per style and preview the ensemble.
- [x] Allow individual vocal parts to be played: soprano, alto, tenor, and
      bass, especially for choir practice. Opt-in original-MIDI track controls
      support naming, per-track instruments, mute, solo, and reset wherever separate tracks exist;
      musical styles are bypassed during practice.
- [x] Add on-demand Spanish instrumental recordings for all 614 New and 527 Old
      hymns, with checked source files, bounded caching, shared playback controls,
      and active-engine completion handling. Retain MIDI controls for verified MIDI.
- [x] Offer sung versions and expand instrumental recordings where verified recordings
      exist, alongside MIDI and video. Download individual recordings on demand
      with bounded caching and the same manual-start/pause/autoplay rules. Do not attach existing MIDI by
      matching hymn numbers across languages; musical styles and choir controls
      require verified MIDI assets or reviewed tune mappings. Audited sung
      Spanish 2009 and Portuguese 1996 and instrumental Russian 1997 recordings
      play on demand. Where a hymn has both, a Sung/Instrumental control in the
      player and in reader options switches between them and saves the choice.
      Further sources are added as they are verified.
- [ ] Add persistent background audio with lock-screen/notification controls,
      headphone actions, interruption handling, and one shared playback queue.
      Start with audio playback; retain each medium's supported behavior. The existing
      engines now publish system media metadata and support play/pause/stop/seek;
      platform background setup and interruption pauses are connected. Audio queue ownership,
      occurrence-aware service boundaries, system next/previous controls, and
      reader catch-up after background advancement are connected. Physical device
      validation remains.

## Design and Consistency

- [x] Give every screen, in every language and both designs, one shared
      component kit: header, cards, rows, pills, search field and sheets, with
      Material widgets mapped to the hymnal palette. Choose any hymnal from one
      header picker; search, topics, A–Z and favorites share one design; the
      reader gathers its options in one sheet. Short phones keep the typed
      number and previews in view. [Design system](docs/design-system.md).

## Browsing and Favorites

- [x] Keep hymn and reading swipes within the selected category or topic,
      wrapping in both directions and displaying the category and position.
- [x] Add interactive page turns for hymns and readings, with top and bottom
      corner folds, a middle page roll, full-page previews, and hymnal logos
      on the reverse near the turning edge.
- [x] Add named favorite categories above the main favorites list. Songs can
      belong to a category independently of the main list; the favorite picker
      supports choosing lists, and category readers support swipe navigation.
- [x] Add a Popular row to the number pad with five random selections from
      the top 20 hymns, refreshed each time the number pad is revisited.
- [x] Keep hymn selection buttons above the number pad for two-line titles,
      and add a hymn-menu option to show or hide chord tabs.
- [x] Allow users to reorder favorites and favorite-category entries.
- [x] Add ordered worship-service playlists, building on favorite categories
      but allowing repeated entries, multiple books, and readings. Preserve the
      chosen sequence for navigation/playback, with readings advanced manually.
      [Editor, navigation, persistence, and validation](docs/service-playlists.md).
- [x] Add a full recently opened history page with book labels and a clear-history
      action, while retaining the quick Recent chips on the number screen.
- [ ] Add locale-aware alphabetical browsing and a jump index for large books.
      Native locale collation, separate browse controls, and letter jumps are
      connected; physical-device UX review remains. [Design and validation](docs/alphabetical-browsing.md).

## Sharing and Presentation

- [x] Let users select, copy, and share a verse or full hymn with its title,
      number, and hymnal edition, preserving stanza and refrain formatting.
- [ ] Explore presentation export for service playlists and lyric slides,
      including VideoPsalm compatibility. This is a proposed extension of the
      Rejnac presentation workflow; live casting is a separate future decision.
      Source-order slides with whole stanzas, preview, offline HTML sharing, and
      a VideoPsalm songbook (`.vpc`) export modelled on a real VideoPsalm file
      are connected; the HTML slides were checked in a browser. Importing the
      `.vpc` file into VideoPsalm on Windows and the physical share sheet remain
      untested. [Progress](docs/service-presentation.md).

## Usage Insights

- [x] Add offline-first analytics with weekly uploads, bounded local storage,
      retry-safe duplicate prevention, country estimation, and developer
      usage/reliability reporting. Statistics are enabled by default, with a
      persistent opt-out in Settings.
- [x] Deploy the serverless collector, aggregate database, private exports,
      Athena reports, privacy-policy endpoint, and suppressed public Trends API.
- [x] Add a dedicated Statistics page in Settings with 1-, 4-, and 8-week
      community reports, accessible charts, hymn links, offline caching,
      reporting dates, and clear suppression/count labels.

- [x] Collect the data needed for top hymns by country, weekday, and broad time
      of day.
- [x] Collect favorite additions, search outcomes, playback reliability,
      reading time, auto-scroll usage, settings changes, and categorized errors.
- [x] Show most-opened hymns, repeat opens within a week, favorite additions,
      popular days/times, and country hymn highlights. New measurements populate
      as weekly uploads meet the minimum of 20 contributors per published group.
- [x] Add separate community counters with accurate weekly contributor counts
      across app versions and entry points, plus resumable deduplicated uploads.
- [x] Deploy a private AWS Amplify dashboard with Cognito administrator sign-in,
      period/platform filters, feature usage, search outcomes, playback health,
      categorized issues, version comparisons, and detailed aggregate counts.

## Release and Privacy Follow-ups

- [x] Publish the updated privacy policy from the live analytics endpoint and
      link it from Settings and About.
- [ ] Verify Google Play Data Safety and Apple App Privacy declarations;
      update them if needed to match the current app. Verified 13 October 2026
      (read-only): Play Console still answers **No** to collecting user data,
      but since 4.3.0 the app collects default-on usage statistics, country,
      diagnostics and optional error reports, so the answer must become **Yes**
      with the data types in [store-privacy-declarations.md](docs/store-privacy-declarations.md).
      The owner needs to submit that change; Apple's App Privacy answers apply
      at the first App Store submission.
- [x] Update the older GitHub Pages privacy-policy copy so older links and
      external references match the current policy. Published and verified
      29 September 2026: https://frazras.github.io/sda_hymnal/privacy-policy.html
      returns the same policy as https://dx289srf77tpf.cloudfront.net/privacy-policy,
      including usage statistics and optional error reports.
- [x] Add release notes explaining default-on statistics, the Settings opt-out,
      offline batching, and the Statistics page.
- [x] Prepare version 4.3.0 source, in-app update history, store notes, and
      signed release artifacts.
- [x] Prepare version 4.6.0 source, translated in-app update history, store
      notes, and a signed release bundle (13 October 2026). Upload to Google
      Play remains the owner's step.
