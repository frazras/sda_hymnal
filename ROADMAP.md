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

- [ ] Add more musical styles.
- [ ] Allow listeners to choose the instruments used for a musical style.
- [ ] Allow individual vocal parts to be played: soprano, alto, tenor, and
      bass, especially for choir practice.

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
- [ ] Update Google Play Data Safety and Apple App Privacy declarations before
      shipping an analytics-enabled app release.
- [ ] Publish the repository-hosted copy of the privacy policy so older links
      and external references remain consistent.
- [x] Add release notes explaining default-on statistics, the Settings opt-out,
      offline batching, and the Statistics page.
- [x] Prepare version 4.3.0 source, in-app update history, store notes, and
      signed release artifacts.
