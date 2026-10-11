import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/hymn_sheet_music.dart';
import 'language_pack_store.dart';
import 'score_pack_store.dart';

/// Download one reviewed page with cancellation and bounded buffering.
Future<Uint8List> downloadScorePage(ScorePackDownload pack, HymnScorePage page,
    LanguagePackCancellation? cancellation,
    {http.Client? client,
    Duration timeout = const Duration(seconds: 30)}) async {
  if (!pack.pages.contains(page)) {
    throw ArgumentError('Page is not part of this score collection');
  }
  final transport = client ?? http.Client();
  try {
    cancellation?.check();
    final request = http.AbortableRequest('GET', pack.urlFor(page),
        abortTrigger: cancellation?.whenCancelled)
      ..followRedirects = false;
    final response = await transport.send(request).timeout(timeout);
    cancellation?.check();
    if (response.statusCode != 200 ||
        (response.contentLength != null &&
            response.contentLength != page.bytes)) {
      throw const FormatException('Score response mismatch');
    }
    final buffer = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream.timeout(timeout)) {
      cancellation?.check();
      received += chunk.length;
      if (received > page.bytes) {
        throw const FormatException('Score exceeds reviewed size');
      }
      buffer.add(chunk);
    }
    cancellation?.check();
    final data = buffer.takeBytes();
    page.validate(data);
    return data;
  } on http.RequestAbortedException {
    cancellation?.check();
    rethrow;
  } finally {
    if (client == null) transport.close();
  }
}
