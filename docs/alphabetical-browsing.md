# Alphabetical browsing

This feature is in progress. Native title collation, a dedicated alphabetical
browse route, and a letter jump picker are connected to paired, individual, and
all-language search screens. Physical-device UX review remains. Number-pad entry
and relevance-ranked search stay intact.

The book language determines title order independently of interface language.
Android uses java.text.Collator with secondary strength and canonical decomposition;
iOS uses Foundation comparison with an explicit locale and case-insensitive options.
Source titles are passed unchanged. Both bridges break equivalent-title ties by
source occurrence index, preserving duplicate entries and exact book identities.
Dart validates that the result is a complete permutation and returns an immutable
index list. Unsupported platforms must not advertise locale sorting through an
ASCII fallback; bridge failures should leave existing browsing usable.

An A–Z icon in existing search controls opens a dedicated browse route, keeping
letter navigation away from the compact search screen. The shortcut is hidden
while a query or keyboard is active, leaving room for translated search actions. The route uses native
sorting and a modal letter picker. Fixed-height rows scale with text size, so a
jump reaches its intended lazy-list row even for long titles. Labels fold Latin
accents but retain Spanish Ñ and Russian letters, including Ё. Only initials
present in the current list are offered.

All-language browsing offers a language selector labelled with source book names;
only that language is sent to its collator. Paired editions retain edition labels.
Opening a hymn gives the reader its alphabetically displayed, same-edition queue.
The original search route retains query relevance ranking and original navigation.
A collation failure offers retry, while Back returns to existing usable search.

Tests cover lazy-row jumping, native failure/retry, mixed-language selection,
letter labels, 320-pixel screens at 4x text size in both designs and themes,
exact-edition reader queue order, and existing paired and imported-book search
and number-pad flows.

References: [Android Collator](https://developer.android.com/reference/java/text/Collator)
and [Foundation comparison](https://developer.apple.com/documentation/foundation/nsstring/compare(_:options:range:locale:)).
