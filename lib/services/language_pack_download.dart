import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'language_pack_store.dart';

/// Stream a pinned text object with bounded memory and verified content.
/// Redirects are rejected so the reviewed HTTPS destination remains explicit.
Future<Uint8List> downloadLanguagePack(LanguagePackDownload descriptor,
    {http.Client? client,
    LanguagePackCancellation? cancellation,
    void Function(int received, int total)? onProgress,
    Duration timeout = const Duration(seconds: 30)}) async {
  final transport = client ?? http.Client();
  try {
    cancellation?.check();
    final request = http.AbortableRequest('GET', descriptor.url,
        abortTrigger: cancellation?.whenCancelled)
      ..followRedirects = false;
    final response = await transport.send(request).timeout(timeout);
    cancellation?.check();
    if (response.statusCode != 200 ||
        (response.contentLength != null &&
            response.contentLength != descriptor.bytes)) {
      throw const FormatException('Language pack response mismatch');
    }
    final buffer = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream.timeout(timeout)) {
      cancellation?.check();
      received += chunk.length;
      if (received > descriptor.bytes) {
        throw const FormatException('Language pack exceeds reviewed size');
      }
      buffer.add(chunk);
      onProgress?.call(received, descriptor.bytes);
      cancellation?.check();
    }
    cancellation?.check();
    final bytes = buffer.takeBytes();
    descriptor.validate(bytes);
    return bytes;
  } on http.RequestAbortedException {
    cancellation?.check();
    rethrow;
  } finally {
    if (client == null) transport.close();
  }
}
