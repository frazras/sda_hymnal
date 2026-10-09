# Service presentation export

This roadmap item is in progress. A source-order slide snapshot and self-contained
HTML renderer, editor preview action, and file-sharing controls are implemented.
HTML browser rendering and physical share-sheet checks, plus VideoPsalm
compatibility, remain before completion.

`ServicePresentation.build` resolves each service occurrence by its full item
reference. Repeated hymns remain separate opening/closing occurrences. Hymn blocks
come from `HymnTextExport`, retaining source stanza/refrain order without adding the
reader's repeated choruses. Readings retain each segment and its speaker role.
The source title, hymn/reading number, book label, and Unicode text remain attached
to every slide. Missing entries, empty entries, and empty reading segments fail the whole
export rather than being silently omitted. Slides are immutable and split at configurable line boundaries,
defaulting to six source lines per slide.

The HTML output embeds its own style and manual Previous/Next and keyboard
Arrow/Page navigation. There is no network dependency, audio, autoplay, casting,
or remote font. User/source text is HTML escaped and never inserted into scripts.
Long lines wrap, and overflowing content can be scrolled; this behavior needs
visual review before claiming a polished projection workflow. Navigation stops
at both ends. Control labels are supplied by the caller for interface localization.

Unit tests verify occurrence order, exactly one source refrain per occurrence,
reading roles, reference preservation, Unicode and HTML escaping, immutable
slides, invalid line limits, missing entries, and empty services. A generated
Spanish preview was produced at `/tmp/service-presentation-preview.html`, but the
browser tool rejected local-file navigation, so browser visual/runtime checks are
not claimed. No workaround was attempted. The service editor now opens a native
slide preview, with bounded Previous/Next controls and Share HTML slides. The
preview supports scrollable long text. Export uses a UTF-8 HTML file through
share_plus temporary storage, a stable filename, and a button-relative iPad
popover anchor. No export is created until the user requests sharing.

Editor tests cover preview/navigation/back across EN/ES/PT/RU, both designs, and
light/dark mode on compact screens. A sharing test inspects the real generated
file at the mocked platform handoff, including Unicode, escaping, MIME type,
filename, and popover bounds. It does not prove a physical recipient app can
open the HTML file. Long-slide tests confirm scrolling and navigation remain
usable at 4x text size on a 320-pixel screen in both designs and themes.

VideoPsalm export should use reviewed schemas and imported sample validation.
An HTML export is not evidence of VideoPsalm compatibility.

Known reading speaker roles are translated using the selected interface language
in both the native preview and exported HTML. Source role IDs and reading text
remain unchanged. Unknown source roles retain their supplied labels. Tests cover
Spanish preview labels and localized HTML without mutating the snapshot.

## VideoPsalm serializer groundwork

`ServicePresentation.videoPsalmSongbook` emits the `Text`, `Guid`, `Songs`, and
`Verses` JSON structure found in the pinned French VideoPsalm source. Each service
occurrence becomes a separate numbered song, so opening and closing repetitions
remain distinct. Slide order, source Unicode lyrics, and localized reading roles
are retained. Generated compact GUIDs use a separate service-export namespace;
source songbook identities are not reused. No source credits or copyrights are
invented.

A generated Spanish two-occurrence fixture was successfully re-imported through
`import_structured_hymnals.convert`, with identical lyric blocks and distinct
occurrences. Dart tests cover JSON decoding, repeated titles, roles, Unicode,
GUID shape, and deterministic output. This proves our adapter round trip, not
native VideoPsalm acceptance. The serializer is not yet exposed in the share UI.

The official [transfer guide](https://myvideopsalm.weebly.com/blog/transfer-songs-from-one-pc-to-another)
distinguishes copied songbooks from portable agendas containing songs and styles.
A songbook JSON file is not a `.vpagd` agenda. Native agenda-schema investigation,
Windows VideoPsalm acceptance, and a clear export-format choice remain before
claiming compatibility or exposing the new format to users.

## Experimental native agenda container

`videoPsalmAgenda` now emits a ZIP container with `Version.json` (2), ordered
`Song_n.json` anchors and matching `SongBook_n.json` definitions, followed by
`AgendaItemProperties.json`. All occurrences advance manually, expose every
slide, and use default verse order. Responsive readings are exported as lyric
slides with roles rather than inventing canonical Bible references. No remote
media or styles are included. This remains unexposed serializer groundwork.

Container ordering and property structure were inspected in the upstream
[agenda parser](https://github.com/g0elles/OpenAdoration/blob/fceb5efb0f0c226bef034680a64a97adac292c3a/OpenAdoration.WPF/Helpers/VideoPsalmMigration/VideoPsalmAgendaParser.cs)
and its
[fixture tests](https://github.com/g0elles/OpenAdoration/blob/fceb5efb0f0c226bef034680a64a97adac292c3a/OpenAdoration.Tests.Infrastructure/VideoPsalmMigration/VideoPsalmAgendaParserTests.cs).
This is independent reverse-engineered evidence, not an official schema or
native acceptance test. Our ZIP regression decodes every entry, checks ordering,
occurrence GUIDs, book definitions, Unicode titles, and aligned manual properties.
Native Windows VideoPsalm validation remains required before offering this format.

The archive dependency is pinned to the already-resolved version 4.0.9, promoted
from transitive to direct; this change adds no new resolved package version.
