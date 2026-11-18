# English 4.5.2 production handoff

Prepared November 17, 2026 on `codex/release-english-4.5.2`, following
English 4.5.1 and the review prompt and lyric correction commits.

| Field | Value |
| --- | --- |
| Version | 4.5.2 |
| Version code | 40502 |
| Play Console release name | 40502 (4.5.2) |
| Package | com.ionicframework.sdanewandoldhymnal816673 |
| AAB | /Users/frazras/Dev/sdahymnal-app-review/build/app/outputs/bundle/release/app-release.aab |
| Size | 64,199,804 bytes |
| SHA-256 | f3edf0f936b0397b07ba8a6dc75eb653c849f3067eee132edff38f42f39d8491 |

Paste these notes into the Production release in Play Console.

```text
<en-US>
Corrected Old Hymnal 18 verse 2 and restored the right lyrics for Old 160 and 161.
Fixed spelling in I Saw One Weary (Old 371 / New 441).
Removed the unrelated video for Old Hymnal 314.
Added Rate this app in Settings. Automatic review requests wait until activities finish, with a shared 30-day cooldown.
</en-US>
```

The bundle includes the English Old and New hymnals, the quiet review requests
from `3d82675`, and the lyric/video corrections from `4751022`.
Automatic review requests share a persisted 30-day cooldown. Android Settings
opens the Play Store for manual reviews. The manual iOS store link becomes
available after an App Store ID is configured.

Old 314's unrelated video assignment was removed. A matching recording remains
unverified.

Verification completed for the production AAB.

- All 43 focused release, hymn-data, video and review tests passed.
- Static analysis found no issues.
- The embedded manifest confirms version 4.5.2, code 40502 and the existing package.
- ZIP integrity and JAR signatures passed verification.
- The signer matches the existing upload certificate, with SHA-256
  `77:7F:AD:B1:FE:41:BB:F1:14:C6:D2:BD:EB:9D:2B:E5:FB:13:87:96:FB:7F:B3:54:5E:1E:FC:E6:DB:77:40:79`.
- Packaged hymn text, video assignments and release history match the source.
- Packaged hymn editions are `old` and `new`.

Upload the AAB above and submit the release through Play Console.
