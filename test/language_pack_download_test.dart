import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sdahymnal/services/language_pack_store.dart';
import 'package:sdahymnal/services/language_pack_download.dart';

void main() {
  final bytes = File('assets/hymnals/sda-es-2009.json').readAsBytesSync();
  final descriptor = LanguagePackDownload(
      bookId: 'sda-es-2009',
      url: Uri.parse('https://example.com/reviewed.json'),
      bytes: bytes.length,
      checksum: sha256.convert(bytes).toString(),
      hymnCount: 614,
      topicCount: 47);

  test('streamed bytes and progress match the reviewed text object', () async {
    final catalog =
        jsonDecode(File('assets/hymnals/catalog.json').readAsStringSync());
    final entry = (catalog['books'] as List).first;
    final reviewed = LanguagePackDownload(
        bookId: entry['id'],
        url: descriptor.url,
        bytes: entry['bytes'],
        checksum: entry['sha256'],
        hymnCount: entry['hymnCount'],
        topicCount: entry['topicCount']);
    final progress = <int>[];
    final client = MockClient.streaming((request, _) async {
      expect(request.url, reviewed.url);
      expect(request.followRedirects, isFalse);
      return http.StreamedResponse(
          Stream.fromIterable([bytes.sublist(0, 12), bytes.sublist(12)]), 200,
          contentLength: bytes.length);
    });
    final downloaded = await downloadLanguagePack(reviewed, client: client,
        onProgress: (received, total) {
      expect(total, bytes.length);
      progress.add(received);
    });
    expect(downloaded, bytes);
    expect(progress, [12, bytes.length]);
  });

  test('cancellation aborts a pending request before headers arrive', () async {
    final cancellation = LanguagePackCancellation();
    final started = Completer<void>();
    final client = MockClient.streaming((request, _) async {
      final abort = (request as http.AbortableRequest).abortTrigger!;
      started.complete();
      await abort;
      throw http.RequestAbortedException(request.url);
    });
    final download = downloadLanguagePack(descriptor,
        client: client, cancellation: cancellation);
    await started.future;
    cancellation.cancel();
    await expectLater(download, throwsA(isA<LanguagePackCancelled>()));
  });

  test('bad status, redirects, lengths and excess bytes fail', () async {
    for (final status in [404, 302]) {
      final client = MockClient.streaming((_, body) async =>
          http.StreamedResponse(const Stream.empty(), status));
      await expectLater(downloadLanguagePack(descriptor, client: client),
          throwsFormatException);
    }
    for (final declared in [bytes.length + 1, null]) {
      final client = MockClient.streaming((_, body) async =>
          http.StreamedResponse(Stream.value([...bytes, 0]), 200,
              contentLength: declared));
      await expectLater(downloadLanguagePack(descriptor, client: client),
          throwsFormatException);
    }
  });

  test('truncated and altered payloads fail integrity checks', () async {
    for (final content in [
      bytes.sublist(0, 12),
      [...bytes.sublist(0, bytes.length - 1), 0]
    ]) {
      final client = MockClient.streaming(
          (_, body) async => http.StreamedResponse(Stream.value(content), 200));
      await expectLater(downloadLanguagePack(descriptor, client: client),
          throwsFormatException);
    }
  });

  test('cancellation and stalled streams terminate without returning a pack',
      () async {
    final cancellation = LanguagePackCancellation();
    final client = MockClient.streaming((_, body) async =>
        http.StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, 12), bytes.sublist(12)]),
            200));
    await expectLater(
        downloadLanguagePack(descriptor,
            client: client,
            cancellation: cancellation,
            onProgress: (_, body) => cancellation.cancel()),
        throwsA(isA<LanguagePackCancelled>()));
    final controller = StreamController<List<int>>();
    final stalled = MockClient.streaming(
        (_, body) async => http.StreamedResponse(controller.stream, 200));
    await expectLater(
        downloadLanguagePack(descriptor,
            client: stalled, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()));
    await controller.close();
  });
}
