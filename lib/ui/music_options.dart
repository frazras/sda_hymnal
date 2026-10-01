import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'instrument_picker.dart';

/// All ensemble instrument configuration stays inside Settings.
class EnsembleInstrumentsPage extends StatefulWidget {
  const EnsembleInstrumentsPage({super.key});
  @override
  State<EnsembleInstrumentsPage> createState() =>
      _EnsembleInstrumentsPageState();
}

class _EnsembleInstrumentsPageState extends State<EnsembleInstrumentsPage> {
  bool busy = false;
  final sample =
      Hymn(number: 108, title: 'Amazing Grace', body: '', version: 'new');

  @override
  void dispose() {
    MidiPlayer.instance.stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Musical style instruments')),
        body: AnimatedBuilder(
          animation: Listenable.merge([
            MusicOptions.instance,
            InstrumentTheme.instance,
            MidiPlayer.instance.current
          ]),
          builder: (context, _) {
            final options = MusicOptions.instance;
            final style = InstrumentTheme.instance.value;
            final playing =
                MidiPlayer.isCurrent(MidiPlayer.instance.current.value, sample);
            return ListView(padding: const EdgeInsets.all(20), children: [
              const Text(
                  'Choose instruments for each musical style. These choices apply to the full ensemble. For Choir practice, choose each track’s instrument in the hymn’s choir mixer.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: style,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Musical style'),
                items: [
                  for (final theme in InstrumentTheme.themes)
                    DropdownMenuItem(
                        value: theme.$1,
                        child: Text(theme.$2,
                            maxLines: 1, overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) {
                  if (value != null) InstrumentTheme.instance.set(value);
                },
              ),
              for (final role in instrumentRoles(style).entries)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (role.key == 9)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Drum kit'),
                            )
                          else
                            InstrumentPicker(
                              key: ValueKey(
                                  '$style-${role.key}-${options.programs(style)[role.key]}'),
                              program: options.programs(style)[role.key],
                              defaultLabel: 'Style default',
                              label: role.value,
                              onChanged: (value) =>
                                  options.setProgram(style, role.key, value),
                            ),
                          Row(children: [
                            Expanded(
                                child: Slider(
                              key: ValueKey('style-volume-${role.key}'),
                              label:
                                  '${options.styleVolumes(style)[role.key] ?? 100}%',
                              semanticFormatterCallback: (value) =>
                                  '${role.value} volume ${value.round()} percent',
                              value:
                                  (options.styleVolumes(style)[role.key] ?? 100)
                                      .toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 100,
                              onChanged: (value) => options.setStyleVolume(
                                  style, role.key, value.round()),
                            )),
                            FilterChip(
                                key: ValueKey('style-solo-${role.key}'),
                                label: const Text('Solo'),
                                selected:
                                    options.styleSolo(style).contains(role.key),
                                onSelected: (value) => options.setStyleSolo(
                                    style, role.key, value)),
                          ]),
                        ])),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          if (playing) {
                            await MidiPlayer.instance.stop();
                          } else {
                            await MidiPlayer.instance.preview(sample);
                            if (MidiPlayer.instance.current.value == null) {
                              throw StateError('Preview unavailable');
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Unable to play the preview. Please try again.')));
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                label:
                    Text(playing ? 'Stop preview' : 'Preview • Amazing Grace'),
              ),
              const Text(
                  'Preview replaces any currently playing hymn and stops when you leave this page.'),
            ]);
          },
        ),
      );
}

class ChoirPartsButton extends StatelessWidget {
  const ChoirPartsButton({super.key, required this.hymn});
  final Hymn hymn;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge(
            [MusicOptions.instance, MidiPlayer.instance.parts]),
        builder: (context, _) {
          if (!MusicOptions.instance.choirPractice) {
            return const SizedBox.shrink();
          }
          final available = MidiPlayer.instance.parts.value.length > 1;
          return TextButton.icon(
            key: const ValueKey('choir-parts'),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(available
                ? 'Choir parts • Original music'
                : 'Separate parts unavailable'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => SafeArea(
                  child: FractionallySizedBox(
                heightFactor: .72,
                child: ChoirPartsPanel(hymn: hymn),
              )),
            ),
          );
        },
      );
}

class ChoirPartsPanel extends StatelessWidget {
  const ChoirPartsPanel({super.key, required this.hymn});
  final Hymn hymn;
  @override
  Widget build(BuildContext context) {
    final player = MidiPlayer.instance;
    final options = MusicOptions.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([
        player.parts,
        player.mutedParts,
        player.soloParts,
        player.current,
        options
      ]),
      builder: (context, _) =>
          ListView(padding: const EdgeInsets.all(20), children: [
        Text('Choir practice', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Original parts only; musical styles are bypassed. Mute silences a part. Solo lets you hear just the selected parts. Mute takes priority. Choose an instrument for each track below. Changes apply to hymn playback and are saved for this hymn. Tap a name to rename it.'),
        if (player.parts.value.length < 2)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                  'This MIDI does not contain separate playable tracks. Individual voices cannot be isolated.'))
        else ...[
          FilledButton.icon(
            icon: Icon(MidiPlayer.isCurrent(player.current.value, hymn) &&
                    !player.current.value!.paused
                ? Icons.pause
                : Icons.play_arrow),
            label: Text(MidiPlayer.isCurrent(player.current.value, hymn) &&
                    !player.current.value!.paused
                ? 'Pause parts'
                : 'Play parts'),
            onPressed: () async {
              try {
                await player.toggle(hymn);
                if (player.current.value == null) {
                  throw StateError('Playback unavailable');
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Unable to play the parts. Please try again.')));
                }
              }
            },
          ),
          for (final part in player.parts.value)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: TextButton(
                            onPressed: () async {
                              final id = '${hymn.version}:${hymn.number}';
                              var editedName =
                                  options.partName(id, part.index, part.name);
                              final name = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        title: const Text('Name this part'),
                                        content: TextFormField(
                                            initialValue: editedName,
                                            onChanged: (value) =>
                                                editedName = value,
                                            autofocus: true,
                                            maxLength: 80,
                                            decoration: const InputDecoration(
                                                hintText:
                                                    'Soprano, Alto, Tenor, Bass…')),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel')),
                                          TextButton(
                                              onPressed: () => Navigator.pop(
                                                  context, editedName),
                                              child: const Text('Save'))
                                        ],
                                      ));
                              if (name != null) {
                                await options.renamePart(id, part.index, name);
                              }
                            },
                            child: Text(
                                options.partName(
                                    '${hymn.version}:${hymn.number}',
                                    part.index,
                                    part.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          )),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            FilterChip(
                                label: const Text('Mute'),
                                selected: player.mutedParts.value
                                    .contains(part.index),
                                onSelected: (value) =>
                                    player.setPartMuted(part.index, value)),
                            FilterChip(
                                label: const Text('Solo'),
                                selected:
                                    player.soloParts.value.contains(part.index),
                                onSelected: (value) =>
                                    player.setPartSolo(part.index, value)),
                          ]),
                        ]),
                        InstrumentPicker(
                          key: ValueKey(
                              'part-instrument-${hymn.version}-${hymn.number}-${part.index}-${options.trackPrograms('${hymn.version}:${hymn.number}')[part.index]}'),
                          program: options.trackPrograms(
                              '${hymn.version}:${hymn.number}')[part.index],
                          defaultLabel: 'Original instrument',
                          onChanged: (value) async {
                            try {
                              await player.setPartInstrument(
                                  hymn, part.index, value);
                            } catch (error) {
                              // Restore the saved choice if the MIDI cannot isolate this track.
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(error is FormatException
                                        ? error.message.toString()
                                        : 'Unable to change this instrument. Please try again.')));
                              }
                            }
                          },
                        ),
                        _TrackVolume(
                          hymnId: '${hymn.version}:${hymn.number}',
                          track: part.index,
                          name: options.partName(
                              '${hymn.version}:${hymn.number}',
                              part.index,
                              part.name),
                          volume: options.trackVolumes(
                                      '${hymn.version}:${hymn.number}')[
                                  part.index] ??
                              100,
                        ),
                      ],
                    ))),
          TextButton(
              onPressed: () => player.resetParts(hymn: hymn),
              child: const Text('Reset mix • Hear all parts')),
        ],
      ]),
    );
  }
}

/// Keep drag feedback local; commit once on release to avoid repeated engine
/// reloads and preference writes while the user's finger is moving.
class _TrackVolume extends StatefulWidget {
  const _TrackVolume(
      {required this.hymnId,
      required this.track,
      required this.name,
      required this.volume});
  final String hymnId;
  final int track;
  final String name;
  final int volume;
  @override
  State<_TrackVolume> createState() => _TrackVolumeState();
}

class _TrackVolumeState extends State<_TrackVolume> {
  double? _dragValue;
  @override
  Widget build(BuildContext context) {
    final value = _dragValue ?? widget.volume.toDouble();
    return SizedBox(
        height: 32,
        child: Row(children: [
          Icon(
              value == 0
                  ? Icons.volume_off_outlined
                  : Icons.volume_down_outlined,
              size: 20),
          Expanded(
              child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16)),
            child: Semantics(
                label: '${widget.name} volume',
                child: Slider(
                  key: ValueKey('track-volume-${widget.track}'),
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  semanticFormatterCallback: (value) =>
                      '${value.round()} percent',
                  onChanged: (value) => setState(() => _dragValue = value),
                  onChangeEnd: (value) async {
                    try {
                      await MusicOptions.instance.setTrackVolume(
                          widget.hymnId, widget.track, value.round());
                    } finally {
                      if (mounted) setState(() => _dragValue = null);
                    }
                  },
                )),
          )),
          SizedBox(
              width: 42,
              child: Text('${value.round()}%',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12))),
        ]));
  }
}
