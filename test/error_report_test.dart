import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/error_reports.dart';
import 'package:sdahymnal/ui/report_error.dart';

void main() {
  Future<void> open(WidgetTester tester, ErrorReportSubject subject,
      Future<void> Function(Map<String, dynamic>) submit) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReportErrorPage(
                                  subject: subject, submit: submit))),
                      child: const Text('Open')),
                ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'prefills selected reading and retains description on failure and retry',
      (tester) async {
    final attempts = <Map<String, dynamic>>[];
    await open(
        tester,
        const ErrorReportSubject(
            kind: 'reading',
            title: 'The Sabbath',
            number: 700,
            edition: 'new',
            itemId: 'reading-700'), (report) async {
      attempts.add(report);
      if (attempts.length == 1) throw Exception('offline');
    });
    expect(find.text('The Sabbath'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).last, 'Wrong word in the response');
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not send'), findsOneWidget);
    expect(find.text('Wrong word in the response'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(attempts.length, 2);
    expect(attempts[0]['id'], attempts[1]['id']);
    expect(attempts.last['item_id'], 'reading-700');
    expect(attempts.last['title'], 'The Sabbath');
    expect(find.textContaining('Thank you.'), findsOneWidget);
  });

  testWidgets('general reports require title and description', (tester) async {
    Map<String, dynamic>? sent;
    await open(tester, const ErrorReportSubject(), (report) async {
      sent = report;
    });
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(sent, isNull);
    expect(find.text('Enter a title'), findsOneWidget);
    expect(find.text('Describe the error'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'Settings issue');
    await tester.enterText(
        find.byType(TextFormField).last, 'The control does not respond');
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(sent?['kind'], 'general');
    expect(sent?['number'], 0);
    expect(sent?['edition'], '');
  });
}
