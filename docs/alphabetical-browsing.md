# Alphabetical browsing

This feature is in progress. The native title-collation bridge is implemented;
search controls, letter jumping, accessibility, and cross-language UI validation
remain before completion. Number-pad entry and relevance-ranked search stay intact.

The book language determines title order independently of interface language.
Android uses java.text.Collator with secondary strength and canonical decomposition;
iOS uses Foundation comparison with an explicit locale and case-insensitive options.
Source titles are passed unchanged. Both bridges break equivalent-title ties by
source occurrence index, preserving duplicate entries and exact book identities.
Dart validates that the result is a complete permutation and returns an immutable
index list. Unsupported platforms must not advertise locale sorting through an
ASCII fallback; bridge failures should leave existing browsing usable.

The API is not yet called by the UI. Integration must cover paired English and
Spanish books, individual imported books, both designs, and the existing filtered
search view. Alphabetical order should be optional, with jump controls appearing
only while browsing alphabetically without a query. A query retains title-first
relevance ranking. Reader and playback queues must use the displayed book order,
with source identities preserved across repeated titles and edition filters.

References: [Android Collator](https://developer.android.com/reference/java/text/Collator)
and [Foundation comparison](https://developer.apple.com/documentation/foundation/nsstring/compare(_:options:range:locale:)).
