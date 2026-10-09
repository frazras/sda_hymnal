import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/service_presentation.dart';

void main() {
  final hymn = Hymn(
      number: 1,
      title: 'Corazón <script>',
      body: '<b>1</b><br>Ábreme<br>Señor<br><br><b>Coro</b><br>Gloria',
      version: 'sda-es-2009',
      languageTag: 'es');
  const reading = AdditionalReading(
      id: 'reading',
      edition: 'sda-es-2009',
      order: 1,
      number: 2,
      title: 'Lectura',
      category: '',
      segments: [
        ReadingSegment(role: 'leader', text: 'Primera\nSegunda'),
        ReadingSegment(role: 'congregation', text: 'Amén')
      ]);
  final repository = HymnalRepository(editions: const [
    HymnalEdition(
        id: 'sda-es-2009',
        languageTag: 'es',
        displayName: 'Español',
        year: 2009)
  ], hymns: [
    hymn
  ], readings: [
    reading
  ]);
  final service =
      ServicePlaylist(id: 'service', name: 'Sábado & domingo', entries: [
    ServiceEntry(id: 'opening', ref: hymn.ref),
    ServiceEntry(id: 'reading', ref: reading.ref),
    ServiceEntry(id: 'closing', ref: hymn.ref),
  ]);
  test('keeps occurrence order, source refrain once and reading roles', () {
    final deck =
        ServicePresentation.build(service, repository, linesPerSlide: 2);
    expect(deck.slides.map((s) => s.occurrenceId).toSet().toList(),
        ['opening', 'reading', 'closing']);
    expect(
        deck.slides
            .where((s) => s.occurrenceId == 'opening')
            .map((s) => s.text)
            .join('\n'),
        '1\nÁbreme\nSeñor\nCoro\nGloria');
    expect(
        deck.slides
            .where((s) => s.occurrenceId == 'reading')
            .map((s) => s.role),
        ['leader', 'congregation']);
    expect(deck.slides.first.ref, hymn.ref);
    expect(() => deck.slides.clear(), throwsUnsupportedError);
  });
  test('HTML escapes source and controls and remains self contained', () {
    final html = ServicePresentation.build(service, repository)
        .html(previousLabel: '<Back>', nextLabel: 'Next & more');
    expect(html, contains('Corazón &lt;script&gt;'));
    expect(html, contains('Sábado &amp; domingo'));
    expect(html, contains('&lt;Back&gt;'));
    expect(html, isNot(contains('<script>Corazón')));
    expect(html, isNot(contains('src=')));
    expect(html, contains('Ábreme'));
  });
  test(
      'missing entries and empty services fail instead of silently omitting content',
      () {
    expect(
        () => ServicePresentation.build(
            ServicePlaylist(id: 'empty', name: 'Empty'), repository),
        throwsFormatException);
    final missing =
        Hymn(number: 99, title: 'Missing', body: '', version: 'sda-es-2009');
    expect(
        () => ServicePresentation.build(
            ServicePlaylist(
                id: 'missing',
                name: 'Missing',
                entries: [ServiceEntry(id: 'x', ref: missing.ref)]),
            repository),
        throwsFormatException);
    expect(
        () => ServicePresentation.build(service, repository, linesPerSlide: 0),
        throwsArgumentError);
  });
}
