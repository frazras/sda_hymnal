# English-only 4.5.1 production handoff

Prepared November 6, 2026 from master 10c7909 on codex/release-english-4.5.1.
The multilingual development branch remains separate.

- Version: 4.5.1
- Version code: 40501
- Release name: 40501 (4.5.1)
- Application ID: com.ionicframework.sdanewandoldhymnal816673
- AAB: /Users/frazras/Dev/sdahymnal-release-english/build/app/outputs/bundle/release/app-release.aab

## Release notes

Jazz accompaniment with phrase-aware melody improvisation.
Optional autoplay for music and hymn videos.
Improved 6/8 timing and melody-track selection.
Clearer number-screen layout and dark-mode menus.

The source base retains English Old/New hymnals. Multilingual hymnals, translated
interface catalogs, and optional language downloads are excluded. The existing
40500 store-note file is retained; 40501 notes omit its Jamaican Gospel and
instrument-picker announcements.

## Verification

- Release AAB built successfully: 63,898,145 bytes.
- Embedded version 4.5.1 / 40501 and application ID verified from the bundle manifest.
- ZIP integrity and JAR signatures verified.
- Release signer SHA-256 matches the existing upload certificate: 77:7F:AD:B1:FE:41:BB:F1:14:C6:D2:BD:EB:9D:2B:E5:FB:13:87:96:FB:7F:B3:54:5E:1E:FC:E6:DB:77:40:79.
- Bundle SHA-256: cb146f04b09f4f883ab48c53c702638500fbc18cdcd519668bf0a1ac03e9debd.
- Embedded hymn data contains only old/new English editions; no multilingual pack folder is bundled.
- All 48 focused release-note, app-design and startup tests passed.
- The earlier full-suite run was interrupted and is not recorded as a passing run.

This handoff does not submit or publish a store release.
