# Product Roadmap

This roadmap lists planned ideas and release follow-ups for the Old and New SDA
Hymnal app. The items are not yet ordered by release or priority.

## Hymnal Content

- [ ] Add sheet music.
- [x] Add all 225 additional readings from the New Hymnal, with categories,
      Scripture references, printed responsive typography, keypad lookup,
      search, swiping, and reading-speed auto-scroll.
- [x] Add searchable hymn and Scripture-reading lists from the New Hymnal
      topical index, while retaining suggested lists for communion, funerals,
      morning and evening worship, Sabbath, and other occasions.

## Music and Choir Features

- [x] Add Jazz with piano chords, walking acoustic bass, swung ride cymbal,
      and customizable ensemble instruments and mix.
- [x] Allow listeners to choose the instruments used for a musical style.
      Opt-in Settings controls save instruments per style and preview the ensemble.
- [x] Allow individual vocal parts to be played: soprano, alto, tenor, and
      bass, especially for choir practice. Opt-in original-MIDI track controls
      support naming, per-track instruments, mute, solo, and reset wherever separate tracks exist;
      musical styles are bypassed during practice.

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
