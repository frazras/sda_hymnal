# Store privacy declarations

What the current app (4.6.0) collects, derived from the code, so the Google Play
Data safety form and Apple App Privacy answers can be checked line by line.
Sources: `analytics/schema.json`, `lib/services/analytics*.dart`,
`lib/services/error_reports.dart`, [analytics.md](analytics.md),
[error-reporting.md](error-reporting.md) and the published
[privacy policy](privacy-policy.html).

## What leaves the device

| Data | When | Linked to a person? | Purpose |
|---|---|---|---|
| Aggregate usage counters: screens opened, hymn/reading numbers opened, favorite adds/removes, search result counts (never search text), settings changes, playback and reader timings | Weekly upload while **Share usage statistics** is on (default on, opt-out in Settings) | No. Weekly-rotating random contributor token, no account | Analytics, app improvement, public community statistics |
| Normalized error categories (playback/content/load failures, Flutter/platform error counts) | Same weekly upload | No | Diagnostics |
| Country | Derived by CloudFront from the upload connection; the IP address itself is not stored | No | Analytics (country statistics) |
| Random contributor token (rotates each reporting week) | Weekly upload | No; deduplication only, not stored as a token server-side | Analytics |
| Error report: title, description typed by the user, hymn/reading identity, random report ID | Only when the user submits **Report Errors** | No account; the text is whatever the user writes | App functionality (content corrections) |
| Requests for optional hymnal text, sheet music and recordings | When the user downloads a book, opens a score pack or plays a recording | No | App functionality (fetched from GitHub over HTTPS) |
| YouTube player traffic | When the user opens a hymn video | Under Google's policy | App functionality (privacy-enhanced embed) |

Not collected: names, email, phone, contacts, precise location, photos, audio
recording, files, payment data, web history, installed apps, advertising ID,
device fingerprints, IP addresses (beyond transient delivery), search text.
No advertising or tracking SDK, no cross-app tracking, no data sale.
All transfers use HTTPS.

## Google Play — Data safety answers

- Does your app collect or share any of the required user data types? **Yes**.
- Is all of the user data encrypted in transit? **Yes**.
- Do you provide a way for users to request that their data is deleted?
  **No account data exists**; users can stop collection and clear local
  analytics in Settings. Answer per the form's wording; aggregated
  contributions cannot be individually deleted (state this in the policy, as it
  already does).
- Data types, all **Collected**, **not Shared**, **processed ephemerally: No**,
  **Optional** (users can turn statistics off), purpose **Analytics** unless noted:
  - Location → **Approximate location** (country from the upload connection).
  - App activity → **App interactions**; **Other user-generated content**
    (error reports — purpose **App functionality**; collected only when the
    user submits a report).
  - App info and performance → **Crash logs** is *not* collected (no crash
    reporter); **Diagnostics** — yes (normalized error counters);
    **Other app performance data** — yes (playback timings).
  - Device or other IDs → **Yes** (weekly random contributor token), purpose
    Analytics, optional.
- Content fetched from GitHub and the YouTube embed are user-initiated content
  delivery, not sharing of user data with a third party.

## Apple — App Privacy answers

- **Data Used to Track You: none.** Tracking: No (no ATT prompt needed).
- **Data Not Linked to You:**
  - Usage Data → **Product Interaction** (Analytics, App Functionality).
  - Diagnostics → **Other Diagnostic Data** (Analytics); **Performance Data**
    (Analytics). Not Crash Data.
  - Location → **Coarse Location** (Analytics) — country from the connection.
  - Identifiers → **Device ID** (Analytics) — the weekly random token. If the
    form's help text treats it as not an identifier because it rotates and is
    not stored, it may be omitted; declaring it is the conservative choice.
  - User Content → **Other User Content** (App Functionality) — error reports.
- **Data Linked to You: none.**

## Verification status (13 October 2026)

- **Google Play — out of date.** Checked read-only in the signed-in Play Console
  (App content → Data safety). The saved answer to "Does your app collect or
  share any of the required user data types?" is **No**. Since 4.3.0 the app
  collects default-on usage statistics, country, diagnostics and optional error
  reports, so this must change to **Yes** with the data types above. Nothing was
  edited; the owner must approve and submit the update (Data safety changes go
  through Google's review).
- **Apple — not yet applicable.** App Store Connect was not signed in on this
  machine, and the iOS build is installed with a personal development team. Fill
  in App Privacy with the answers above when the app is first submitted to the
  App Store.

The privacy policy at `https://dx289srf77tpf.cloudfront.net/privacy-policy`
already describes all of these flows, including default-on statistics with an
opt-out and error reports.
