import 'dart:convert';
import 'dart:io';

import '../models/release_notes.dart';
import 'analytics_endpoint.dart';

class ErrorReportSubject {
  final String kind;
  final String title;
  final String edition;
  final String itemId;
  final int number;

  const ErrorReportSubject(
      {this.kind = 'general',
      this.title = '',
      this.edition = '',
      this.itemId = '',
      this.number = 0});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'edition': edition,
        'item_id': itemId,
        'number': number,
      };
}

/// Explicitly submitted feedback is independent of optional usage statistics.
class ErrorReports {
  static Future<void> submit(Map<String, dynamic> report) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      await (() async {
        final request = await client
            .postUrl(Uri.parse('$analyticsEndpoint/v1/error-reports'));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({...report, 'version': appReleaseVersion}));
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode != 201) {
          throw const HttpException('Report not accepted');
        }
      })()
          .timeout(const Duration(seconds: 25));
    } finally {
      client.close(force: true);
    }
  }
}
