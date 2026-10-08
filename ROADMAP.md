# Product Roadmap

This roadmap lists planned ideas and release follow-ups for the Old and New SDA
Hymnal app. Checkboxes describe implementation status. The next-work sequence
below is recommended; it is not a promised release schedule.

All work must follow the [UX contract](docs/ux-contract.md): preserve the shared
number pad, pair related editions, keep reader controls coherent, and check
small-screen layouts before adding more features.

## Recommended Next Work

1. Maintain a consistent number-pad and reader experience across languages,
   including paired Old/New Spanish hymnals. Preserve clarity and avoid crowding.
2. Extend favorite ordering into service playlists as practical worship
   tools while preserving the shared reader and uncluttered menus.
3. Prioritize verified cross-language music, translated menus, background
   playback, and optional downloadable packs. Continue reviewed language
   expansion; explore presentation export later. Custom songbook imports are
   outside the active roadmap.

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
- [ ] Extend deployed analytics/error-report schemas to native book identities.
      Until deployed, suppress foreign per-hymn statistics and submit foreign
      content reports as general reports with the correct book/title context.
- [x] Import Spanish 2009 (614 hymns), Spanish 1962 (527), Portuguese 1996 (610),
      and Russian 1997 (385) from pinned GoGoShift sources, including their topic
      indexes. Keep existing English corrections and music mappings.
      [Source and validation details](docs/language-packs.md). Reader/selector
      integration remains the separate item above.
- [ ] Build repeatable source importers and a content validation report for
      GoGoShift text, VideoPsalm JSON, and structured verse/refrain JSON. Track
      provenance and reviewed overrides; catch duplicate numbers, empty lyrics,
      numbering gaps, invalid references, and missing media before publishing.
- [x] Add French Hymnes et Louanges (520) and Swahili Nyimbo za Kristo (220)
      through the shared keypad/search/reader; retain unknown edition years and
      omit unavailable topics/media.
- [ ] Expand to the remaining reviewed Rejnac collections.
      Validate edition/language labels and disclose partial coverage; resolve
      known empty entries and duplicate numbers instead of silently renumbering.
- [ ] Offer Tagalog and Cebuano as explicitly partial collections (237 records
      each in the audited source), plus optional Adventist Youth, Scripture-song,
      and supplemental songbooks. Preserve their source page numbering.
- [ ] Let users download, update, and remove optional language, score, and audio
      packs. Show size and coverage, verify checksums, activate updates atomically,
      preserve the last working version and saved favorites, and keep the current
      English books available offline.
- [ ] Localize the app interface independently of the selected book, starting
      with Spanish, Portuguese, and Russian; add a reviewed community translation
      workflow. Support script/font needs and future right-to-left books.
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
- [ ] Offer sung versions and expand instrumental recordings where verified recordings
      exist, alongside MIDI and video. Support optional offline downloads and
      the same manual-start/pause/autoplay rules. Do not attach existing MIDI by
      matching hymn numbers across languages; musical styles and choir controls
      require verified MIDI assets or reviewed tune mappings.
- [ ] Add persistent background audio with lock-screen/notification controls,
      headphone actions, interruption handling, and one shared playback queue.
      Start with audio playback; retain each medium's supported behavior.

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

## Sharing and Presentation

- [x] Let users select, copy, and share a verse or full hymn with its title,
      number, and hymnal edition, preserving stanza and refrain formatting.
- [ ] Explore presentation export for service playlists and lyric slides,
      including VideoPsalm compatibility. This is a proposed extension of the
      Rejnac presentation workflow; live casting is a separate future decision.

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
      update them if needed to match the current app. The earlier analytics
      handoff recorded no store-console changes; current console answers have
      not been verified, so this is a verification follow-up, not a confirmed
      missing submission.
- [x] Update the older GitHub Pages privacy-policy copy so older links and
      external references match the current policy. Published and verified
      29 September 2026: https://frazras.github.io/sda_hymnal/privacy-policy.html
      returns the same policy as https://dx289srf77tpf.cloudfront.net/privacy-policy,
      including usage statistics and optional error reports.
- [x] Add release notes explaining default-on statistics, the Settings opt-out,
      offline batching, and the Statistics page.
- [x] Prepare version 4.3.0 source, in-app update history, store notes, and
      signed release artifacts.
