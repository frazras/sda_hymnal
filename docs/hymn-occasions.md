# Topical index and occasion lists

The New Hymnal lists combine the physical hymnal's photographed topical index with all 16 existing editorial occasion lists. Existing IDs, New Hymnal memberships, Old Hymnal memberships, and popularity ordering are preserved. Corresponding occasion titles are renamed to the printed headings; the previous names remain searchable. Funerals, Children & youth, and Christmas remain as additional occasion lists.

## Sources and regeneration

- `tool/data/topical_index/new_hymnal.tsv` transcribes the 65 populated headings, in printed order, with separate hymn and reading references and the source image suffixes. Columns are title, hymn numbers, reading numbers, and photo suffixes.
- Source photographs are IMG_3638.JPG, IMG_3641.JPG through IMG_3653.JPG, supplied by the user. IMG_3652 and IMG_3653 photograph the same final page; only one transcription is used. Continued columns and pages are joined under their preceding heading.
- `tool/data/topical_index/cross_references.json` records the printed “See” references as searchable aliases, rather than creating duplicate lists. Broad parent references expand to their populated subtopics. References to separate indices (Canons and Children's Hymns), or unspecified individual topics/doctrines, contain no memberships in these photos and are not invented.
- Run `python3 tool/build_topical_index.py` from the checkout to regenerate `lib/models/topical_index.g.dart`. The generator validates catalog references and formats the Dart output.
- Source photos are not bundled in the app. `source_photos.json` records their SHA-256 hashes for provenance.

## Reference corrections and editorial additions

Printed reference errors are resolved by the existing reading titles and content:

| Photo / topic | Printed entry | Resolved reference |
|---|---|---|
| IMG_3643 / God the Father: Faithfulness | He That Dwelleth in the Secret Place — 222 | Reading 722 (222 is a hymn) |
| IMG_3646 / Jesus Christ: Birth | The Incarnate Word — 843 | Reading 844; 843 is In Praise of Christ |
| IMG_3652 / Stewardship | Generosity — 823 | Reading 821; 823 is Temperance |
| IMG_3652 / Watchfulness | Christ's Second Coming — 746 | Reading 747; 746 is Signs of Christ's Coming, also retained |

The printed New Year list gives both “All ye mountains, praise the Lord” and “Now the joyful bells a-ringing” the number 23. This remains one membership, resolved to the catalog's hymn 23. Psalm 98 resolves to reading 859 (catalog title “Calls to Worship”, Scripture reference Psalm 98).

Pilgrimage includes an editorial addition of hymn 622, the alternate setting of “Come, Come, Ye Saints”, alongside the printed 629. The transcription itself retains the printed references. Together the topics cover all 695 New Hymnal songs. The generated index contains 885 hymn memberships and 294 reading memberships; shared selections appear in multiple topics. Existing occasion additions remain on top of these counts.

## Old Hymnal

Old Hymnal lists are derived suggestions, not a transcription of an Old Hymnal topical index. The generator uses local metadata cross-references and exact normalized title matches, and retains every existing Old Hymnal selection. It never copies New Hymnal numbers into the Old Hymnal by number alone.

Additional editorial selections use existing Old Hymnal content:

- Christian Life: counterparts of New 306, 309, 330, and 590 where available.
- Health and Wholeness: Old 530, The Great Physician Now Is Near.
- Law and Grace: Old 163, There Is a Fountain; Old 592, Lord Jesus, I Long to Be Perfectly Whole.
- New Year: Old 480, A Year of Precious Blessings.
- Obedience: Old 288, O Jesus, I Have Promised; Old 429, Jesus, I Will Follow Thee; Old 279, Live Out Thy Life Within Me.
- Spiritual Gifts: Old 207, Let Thy Spirit, Blessed Saviour; Old 658, They Brought Their Gifts to Jesus.

No Old Hymnal matches were found for the Spirituals genre, so that edition shows an empty-state message. New Hymnal reading references are never applied to the Old Hymnal. Existing song metadata categories and the separate reading catalog/categories are unchanged.

## App behavior and validation

The existing “Hymns by occasion” entry opens the searchable topical lists. Topic pages show songs followed by clearly labeled Scripture readings. Song popularity only reorders songs; readings retain index order and open in `AdditionalReadingPage`. Loading failures offer a retry without hiding the songs.

`test/hymn_occasions_test.dart` checks additive preservation, catalog validity, complete photographed memberships, all-song coverage, duplicate prevention, reading navigation, edition isolation, previous-name and cross-reference searches, classic and modern hymn navigation, and narrow-screen large-text layout.
