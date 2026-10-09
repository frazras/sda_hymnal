# Service presentation export

This roadmap item is in progress. A source-order slide snapshot and self-contained
HTML renderer are implemented. Editor export/share controls, user preview, visual
rendering checks, and VideoPsalm compatibility remain before completion.

`ServicePresentation.build` resolves each service occurrence by its full item
reference. Repeated hymns remain separate opening/closing occurrences. Hymn blocks
come from `HymnTextExport`, retaining source stanza/refrain order without adding the
reader's repeated choruses. Readings retain each segment and its speaker role.
The source title, hymn/reading number, book label, and Unicode text remain attached
to every slide. Missing or empty entries fail the whole export rather than being
silently omitted. Slides are immutable and split at configurable line boundaries,
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
not claimed. No workaround was attempted. No export menu is connected yet.

VideoPsalm export should use reviewed schemas and imported sample validation.
An HTML export is not evidence of VideoPsalm compatibility.
