# App review requests

Automatic requests use the Android and iOS native review APIs. A shared,
persisted 30-day cooldown starts before calling the store, including when the
store silently suppresses its dialog. Store quotas control actual visibility.

Requests are eligible after these routines finish.

- Add a favorite, after closing the category chooser if it is shown.
- Complete MIDI playback outside a category or favorites list, with autoplay off.
- Complete auto-scroll, after a five-second quiet period.
- Return from the Settings tab to the Numbers home screen.

Active MIDI playback (including paused playback), video, or auto-scroll suppresses
a request. Opening a modal, navigating away, touching the app, restarting an
activity, or backgrounding the app cancels or suppresses a delayed request.
Skipped requests leave the cooldown available for another eligible routine.

Settings includes **Rate this app** on Android. It opens the Play Store listing
and postpones automatic requests for 30 days. Explicit manual requests remain
available during the cooldown. Store-link failures show a retry message.

Automatic iOS requests are implemented. The manual iOS row becomes available
when building with `--dart-define=APP_STORE_ID=<numeric Apple ID>` after an App
Store listing exists. No App Store ID is configured yet.

The stores require their native review UI and prohibit an enjoyment question
before the rating prompt. Android review UI needs a Play-installed build or an
internal testing/sharing installation. Local iOS builds can show a test dialog;
TestFlight suppresses review requests. A request cannot confirm that a user
submitted a review.
