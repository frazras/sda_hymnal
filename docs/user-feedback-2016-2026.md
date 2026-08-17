# User bug reports, 2016–2026: analysis and fix list

**Source:** the in-app "bug report" Google Form, 3,863 responses collected 28 Feb 2016 – 2026.
**Compiled:** 17 August 2026, ahead of the 4.0.0 Play Store release.
**Status of this document:** working fix list. Items are marked ✅ fixed, ⬜ open, or ⛔ do-not-change.

---

## Summary

Users have been telling us the same three things for ten years:

1. **Give us the tunes.** The single most requested feature, by a wide margin — 272 of 1,469 written suggestions (18.5%) ask for music. **4.0.0 delivers this.**
2. **Fix the words.** 1,563 people (40% of all responses) said they had found a lyric error; 1,414 named a hymn. **Still open — this document is the fix list.**
3. **Make the text bigger.** 101 mentions. **4.0.0 delivers this** (adjustable text size).

The reports are also *accurate*. Where this analysis was able to check a claim against the shipped data or against the printed hymnal, users were usually right — including a navigation bug seven people described precisely and which sat unfixed for years (§5.1).

One caution runs through the whole document: **the SDA Hymnal's texts differ from other denominations' hymnals**, and a meaningful share of "errors" are really that difference. Fixing those would corrupt the app for its actual audience. Those cases are listed in §4 and must not be "corrected".

### Response profile

| | |
|---|---|
| Responses | 3,863 |
| Peak years | 2017 (1,196) and 2018 (1,205) |
| Reported a lyric error | 1,563 (40%) · 1,944 said no |
| Named a hymn | 1,414 responses → 248 distinct hymn numbers |
| Written suggestions | 1,469 |
| Net Promoter Score | **+42** (avg 8.21/10, 1,557 promoters vs 497 detractors) |
| Sentiment | Happy 1,482 · Very Excited 1,213 · No Emotion 352 · Annoyed 161 · "I hate this app!" 81 |

Negative sentiment peaked in 2018 (92 responses) and has been in single digits since 2021 — though so has response volume, since the form is only reachable from an app that stopped being updated.

---

## 1. What users asked for

Ranked by mentions across the 1,469 written suggestions. Themes are keyword-matched, so a response asking for two things counts in both.

| Rank | Request | Mentions | Status in 4.0.0 |
|---:|---|---:|---|
| 1 | **Music / tunes / audio** | 272 (18.5%) | ✅ All 695 New-Hymnal tunes play, with 8 instrument voices |
| 2 | **Fix lyric errors / let us report them** | 138 (9.4%) | ⬜ This document; see §3 |
| 3 | **Bigger / adjustable font** | 101 (6.9%) | ✅ Adjustable text size in Settings |
| 4 | **Better search** | 72 (4.9%) | ✅ Full-text search across titles and lyrics |
| 5 | **Offline / smaller download** | 44 (3.0%) | ✅ Still fully offline (55 MB) |
| 6 | **Share / copy / project lyrics** | 36 (2.5%) | ⬜ Not implemented |
| 7 | **Favorites / bookmarks** | 30 (2.0%) | ✅ Favorites tab |
| 8 | **Scrolling / navigation** | 20 (1.4%) | ✅ Rebuilt; see §5.1 |
| 9 | **Responsive readings / other books** | 12 (0.8%) | ⬜ Not implemented |
| 10 | **Night / dark mode** | 10 (0.7%) | ✅ Light, dark, and system themes |
| 11 | **Sheet music / notation / solfa** | 9 (0.6%) | ◐ Partial — chord tabs, not notation |
| 12 | **Speed / performance** | 9 (0.6%) | ✅ Rebuilt on Flutter |

**Eight of the top twelve requests ship in 4.0.0.** The largest outstanding ask is the lyric corrections below; after that, "share / project the lyrics" (36 mentions) is the biggest unbuilt feature, which matters because it is a *worship-leader* request — projecting words for a congregation.

Also requested, below the threshold: other-language hymnals (Shona, Bemba, Twi, siSwati and more — 9 mentions), a hymn-of-the-day, and the ability to submit corrections in-app.

---

## 2. How the defects were verified

Three independent passes, and a claim is only marked **confirmed** where at least two agree:

1. **What users said** — all 3,863 responses mined for concrete, actionable claims (a wrong word, a missing verse, a mislabeled chorus), discarding the ~85% that are blank, praise, or a bare hymn number.
2. **What the data says** — every one of the 694 New-Hymnal records inspected structurally, and each record diffed word-by-word against the *same hymn's* copy in the Old-Hymnal half of the same file. That cross-book diff is the highest-yield check available and needs no external source: it isolates single-token corruption that no structural scan can see.
3. **What the hymnal says** — the most-reported hymns cross-referenced against SDA-specific sources (Hymnary's SDAH1985 entries, sdahymnals.com, hymnsforworship.org, bibleuniverse.com, adventisthymns.com and several independently maintained SDA datasets), *not* generic hymn sites.

**Known limit:** no source consulted is a scan of the printed 1985 hymnal — Hymnary hosts no scan (the book is still in copyright) and the Internet Archive copy is lending-restricted. Many online "SDA" lyric sites also share one upstream lineage, so agreement between them is weaker evidence than it looks. Where a fix rests on that lineage alone it is marked *likely*, not *confirmed*, and **anyone with a physical hymnal can settle those in seconds** — the page numbers are in the tables.

---

## 3. Confirmed content defects

### 3.1 Hymn 88 — *I Sing the Mighty Power of God* · **139 reports** (by far the most-reported)

Verse 2 is correct. Verse 1 has one error; the whole second half of verse 3 is the **wrong textual variant** — the app carries the altered reading used by most non-SDA hymnals, where the SDA Hymnal keeps Watts's 1715 original. Six differing lines out of 24. Confidence: confirmed (Hymnary SDAH1985 + sdahymnals.com word-for-word, four further sources on verse 3).

| Location | App has | Should be |
|---|---|---|
| v1 L1 | "the **almighty** power of God" | "the **mighty** power of God" |
| v3 L4 | "from thy **thrown**;" | "from Thy **throne**;" |
| v3 L5 | "**While all that borrows** life from thee" | "**Creatures that borrow** life from thee" |
| v3 L6 | "**Is ever in** thy care;" | "**Are subject to** Thy care;" |
| v3 L7 | "And everywhere that we can be," | "There's not a place where we can flee" |
| v3 L8 | "Thou, God, art present there." | "But God is present there." |

The v1 L1 error is why this hymn dominates the reports: the app's own **title** says "Mighty" while the first line displayed says "almighty". 13 users typed the title instead of a number.

⛔ **Do not touch** v1 L7 "at **God's** command", v2 L2 "**Who** filled the earth", v2 L3 "**Who** formed the creatures **thru** the Word". These look wrong against a generic hymnal and are correct SDA readings. "thru" is deliberate SDA orthography, not a typo.

### 3.2 Hymn 505 — *I Need the Prayers* · **30 reports** — structural

Users described this precisely: *"the second chorus is actually the third verse"*. The record has **2 numbered verses and two blocks both labeled CHORUS**; the hymnal has **3 verses and one refrain**. The second "CHORUS" block is verse 3, wrongly labeled and styled.

Fix: relabel that block `3`, change its marker color from the chorus gold `#CD9B1D` to the verse green `#0B6138`, and remove the `<i>` italics wrapper. Confirmed.

### 3.3 Hymn 440 — *How Cheering Is the Christian's Hope* · 18 reports — **content actually missing**

The most severe defect found. Verse 2 is degenerate: its first couplet and second couplet are the *same* couplet, which also duplicates verse 1's second couplet. **Verse 2 contains no unique text at all** — its real content was overwritten. 93 words here against 115 in the Old-Hymnal copy (Old #387), which contains two stanzas with no counterpart in this record. Also: "bouys" for "buoys", three times.

This one needs re-sourcing from the printed hymnal, not a word swap.

### 3.4 Hymn 247 — *Come, My Way* · 16 reports — **wrong hymn entirely**

The title is "Come, My Way" but the body is a different hymn — the text also stored at 248 (*O, How I Love Jesus*); the two share 90.5% of their vocabulary. Either the body must be replaced with the correct text, or 247's title is wrong. Needs the printed hymnal to decide. Three users reported "247 title is wrong".

### 3.5 Hymn 254 — *The Great Physician Now Is Near* · 19 reports — **verse numbering broken**

Verse markers read **1, 2, 4, 4** — no verse 3, and 4 used twice. The *content* is complete (113 words vs Old #530's 113), so this is purely a labeling fix: renumber the third block to 3. One of only two records in the entire book with broken numbering (the other is 409: 1, 2, 2, 4).

### 3.6 Single-word corruptions — confirmed, one-character fixes

Each was found independently by users *and* by the cross-book diff.

| Hymn | Reports | Location | App has | Should be |
|---:|---:|---|---|---|
| 394 *Far From All Care* | 47 | v3 L4 | "hallowed **ret**." | "hallowed **rest**." |
| 321 *My Jesus, I Love Thee* | 26 | v3 L4 | "**iI** ever I loved Thee" | "**If** ever I loved Thee" |
| 382 *O Day of Rest and Gladness* | 25 | v1 L6 | "Who bend before throne," | "Who bend before **the** throne," |
| 336 *There Is a Fountain* | 20 | v6 | "ransomed from **the the** grave" | "from the grave" |
| 336 *There Is a Fountain* | 20 | v6 L3 | "ransomed from the **grace**;" | "from the **grave**;" |
| 384 *Safely Through Another Week* | 22 | v4 | "Till **we we** rise to reign" | "Till we rise to reign" |
| 435 *The Glory Song* | 21 | v1 | "labors and **trails** are o'er" | "**trials**" |
| 435 *The Glory Song* | 21 | v3 | "just a smile **form** my Savior" | "**from**" |
| 3 *God Himself Is With Us* | 34 | v1 L7 | "lowly,Yield" (missing space) | "lowly, Yield" |
| 534 *Will Your Anchor Hold* | 17 | v3 | "in the straits of **F**ear" | "fear" |
| 348 *The Church Has One Foundation* | 16 | v1 L2 | "Tis Jesus Christ" | "'Tis Jesus Christ" |

Two of these — 394 and 382 — have the **identical typo in the Old-Hymnal record of the same hymn** (Old #468 and Old #463). Fix both copies.

Hymn 3 additionally uses British spellings ("splendour", "honour", "endeavour") where the 1985 hymnal prints American ones — confirmed, low risk.

### 3.7 Reported but not yet verified

Named by users, not yet checked against the hymnal. Each is plausible and specific:

| Hymn | Claim | Reports |
|---|---|---:|
| Old 533/534/535 | Whole block shifted: 533 shows 534's text, 534 shows 535's | several |
| Old 574 | "**Sins** them over again to me" → "**Sing**" | 4 |
| Old 576 | Stanzas 2 and 3 are identical | 1 |
| 412 *Cover With His Life* | "whither" → "whiter" (whiter than snow) | 4 |
| 43 | Verses 2–3 drop "be" — "May Jesus Christ **be** praised" | 2 |
| 295 | "brance" → "branch"; "believe" misspelled in v3 | 3 |
| 305 *Give Me Jesus* | Verse 1's last line sits inside the chorus block | 1 |
| 612 | v2 L2 "brother" → "Christian" | 1 |
| 665 | v1 missing "thy" before "guiding" | 2 |
| 208 | "vally" → "valley" | 1 |
| 160 | *O Thou in Whose Presence* missing entirely | 1 |
| 331 | Last two verses run together | 1 |
| 218, 625, 618, 1, 229 | ✅ Checked — **no defect found**, see §4 | 15–28 each |

---

## 4. ⛔ Reported, but the app is RIGHT — do not "fix"

This section exists because acting on these reports would *introduce* errors. In each case the app matches the SDA Hymnal and the reporter was comparing against a different tradition's version.

| Hymn | What users report | Reality |
|---|---|---|
| **229** *All Hail the Power* | "v4 'angel throng' should be 'sacred throng'" (28 reports) | App is **word-for-word identical** to the SDAH1985 text, 137/137 words, zero differences. "Sacred throng" is the pre-1985 / other-tradition reading. **Do not change.** |
| **321** *My Jesus, I Love Thee* | v3 "'til death" looks wrong | SDA Hymnal reads "I will love Thee **'til** death"; every other hymnal reads "**in** death". App is correct. (Its real defect is the separate "iI" typo, §3.6.) |
| **205** *Gleams of the Golden Morning* | Refrain wording | App's "O, **we** see the gleams" and "**His**" are the 1985 readings, confirmed against the printed music. Hymnary and the sites mirroring it print the older 1880 text. **Do not change the refrain.** |
| **382 / 383** | "382 and 383 are duplicates, one is wrong" | The hymnal prints this text **twice** with different tunes, and the two differ deliberately ("reach the rest…blessed" vs "seek the rest…blest"). **Do not harmonize them.** |
| **625** *Higher Ground* | Wording differences vs Old #631 | The 1985 revision, not corruption. |
| **618** *Stand Up for Jesus* | — | "vict'ry" elision is consistent house style. No defect. |
| **1** *Praise to the Lord* | "missing ~3 verses" | Both copies in the file carry 3 stanzas and agree word-for-word. Cannot be confirmed as truncated; verify against print before acting. |
| **142** | v1 "matches the Christmas carol, not the hymnal" | Worth checking, but this is the classic shape of a cross-tradition report. |

**Rule of thumb for every future correction: verify against an SDA source, never a generic hymn site — and prefer the printed 1985 hymnal over any website.**

---

## 5. App bugs users reported

### 5.1 ✅ "Hymns 313, 314, 315 freeze — the page will not advance" (7 reports) — **FIXED**

Seven people described this exactly. It was real, and its cause was found independently during the 4.0.0 pre-flight audit: `hymns.json` carried **313 twice** (once complete, once as a one-verse stub) and **no 314 at all**, while every lookup indexed by list position. Typing 314 opened the stub labeled 313; pressing next from 313 landed on that same stub forever.

Fixed in commit `beca185`: the stub is gone, lookups are keyed by hymn *number*, and paging steps over a missing number (313 → 315). Guarded by `test/hymn_data_test.dart`.

⬜ **Hymn 314's words are still missing** — they were never in the app, and the defect traces to the original 2016 Ionic data (`www/js/index.xml`, where the `threeonefour` record is a mislabeled copy of 313). `assets/midi/314.mid` ships and is ready. Supplying the text of *"Just as I Am, Thine Own to Be"* closes this.

### 5.2 Other reported bugs

| Bug | Reports | Status |
|---|---:|---|
| No audio / no way to play a tune | 27 across variants | ✅ 4.0.0 adds playback |
| Text too small, no zoom | 18 | ✅ Adjustable text size |
| App slow / laggy / slow search | 15 | ✅ Rebuilt on Flutter; search is in-memory |
| Can't find or install from Play Store | 6 | ◐ Likely the 2020-era compliance warnings; 4.0.0 restores an active listing |
| Search returns nothing for titles that exist | 8 | ✅ Rebuilt full-text search — **worth re-testing** |
| Typing a number opens the wrong hymn | 3 | ✅ Same root cause as §5.1 |
| Lyrics render truncated, only first lines | 2 | ⬜ Possibly the 313 stub; possibly others — see §6 |
| App won't start / freezes | 5 | ✅ Presumed fixed by the rebuild; unverifiable from here |

---

## 6. Systemic data-quality findings

From scanning all 694 New-Hymnal records. These are the checks worth automating, ranked by yield.

| Pattern | Affected | Note |
|---|---:|---|
| **Cross-book single-token corruption** | 6 confirmed in 20 sampled | Diffing each new record against the Old-Hymnal copy of the same hymn found every one-letter defect above. ~600 hymns appear in both books; **running this over all of them is the single highest-value action in this document.** |
| Chorus placement anomalies | 18 | 8 records place a chorus after the last verse (84, 140, 141, 201, 425, 452, **505**, 622); 3 place it before verse 1 (93, 362, 438); 7 repeat the label (121, 140, 152, 368, 425, 472, 505) |
| Verse ends without terminal punctuation | 36 | Signal of truncation. Includes 3, 205, 254, 440 |
| Whole body ends unpunctuated | 10 | 99, 162, 189, 254, 369, 436, 609, 651, 667, 685 |
| Duplicate / near-duplicate bodies | 8 (4 pairs) | 489/490 identical; 694/695 98.4%; 382/383 97.3% (deliberate); **247/248 90.5% — a real defect** |
| Title text absent from body | 24 | Mostly benign, but caught **88** and **247**. Worth a manual pass |
| Verse shorter than its siblings | 11 | 14, 38, 47, 120, 133, 169, 234, 387, 553, 560, 614 — unchecked |
| Doubled consecutive word | 3 | 255 (legitimate), **336**, **384**. Cheap check, near-zero false positives |
| Broken markup | 4 | **428** contains a literal `&lt;)br/&gt;`; 262 has a stray "GBP"; 187 has an editorial bracket; 694 a stray `<` |
| Italic wrapper closes after `<p></p>` | 10 | 14, 302, 305, 307, 311, 317, 505, 531, 539, 561 |
| Trailing whitespace / doubled spaces | 119 / 21 | Cosmetic |
| Verse numbering not 1..k | 2 | **254** (1,2,4,4) and **409** (1,2,2,4) |
| Leftover `hymn_key_note` markers | 0 | Clean |
| Unbalanced HTML tags | 0 | Clean |

### Recommended CI checks

Cheap, high-signal, and they would have caught most of the above before release. `test/hymn_data_test.dart` already covers the first two:

1. ✅ No repeated hymn numbers; no body that is a strict prefix of another under the same title.
2. ✅ Both hymnals complete (New 1–695 less the documented 314 gap; Old 1–703).
3. ⬜ Doubled consecutive words.
4. ⬜ Verse markers strictly 1..k.
5. ⬜ Chorus never before verse 1 or after the last verse.
6. ⬜ Every verse ends with terminal punctuation.
7. ⬜ Cross-book diff: flag any new/old pair of the same hymn differing by exactly one token.

---

## 7. Suggested order of work

**Before the next release** (all mechanical, all confirmed, ~1 hour):
1. The 11 single-word fixes in §3.6, plus the two Old-Hymnal twins.
2. Hymn 505's verse-3 relabel (§3.2) and hymn 254's renumber (§3.5).
3. Hymn 88's six lines (§3.1) — highest report count in the entire dataset.
4. Hymn 428's broken markup.

**Needs a printed hymnal** (someone must open the book):
5. Hymn 440's overwritten verse 2 (§3.3) and hymn 247's wrong body (§3.4).
6. Hymn 314's missing text (§5.1).
7. Confirm hymn 205's verse 4 (§3.6 marked *likely*).

**Then automate** (§6) so none of this recurs, and re-run the cross-book diff over all ~600 shared hymns to find the defects nobody happened to report.

**Product:** the one large unbuilt request is **share / project lyrics** (36 mentions), aimed at worship leaders.

---

## 8. Provenance and privacy

- Source file: *"Welcome to our bug report form (Responses) — Form Responses 1.csv"*, 3,863 data rows, exported 17 Aug 2026.
- **The raw CSV is deliberately NOT committed to this repository.** 658 responses contain personal email addresses, given by people expecting a reply about their hymn, not publication in a public git history. Keep it in private storage. Every figure here is aggregate, and every quote was stripped of identifying detail.
- 658 people asked to be contacted when their correction was made. Many of these fixes are theirs. If you ever ship them, those addresses are a mailing list of your most engaged users — worth a note that their report was acted on, years later.

---

*Analysis by Claude Code, 17 Aug 2026. Report counts are from the form; defect verification is from the shipped `assets/hymns.json` and the SDA-specific sources listed in §2. Where a correction is marked "likely" rather than "confirmed", it rests on online transcriptions that may share a single upstream — check the printed hymnal before shipping those.*
