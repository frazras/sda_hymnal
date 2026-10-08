import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/error_reports.dart';
import 'package:sdahymnal/ui/report_error.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/theme.dart';

void main() {
  Future<void> open(WidgetTester tester, ErrorReportSubject subject,
      Future<void> Function(Map<String, dynamic>) submit,
      {Locale? locale, bool classic = false, bool dark = false}) async {
    await tester.pumpWidget(MaterialApp(
        locale: locale ?? const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light,
            classic: classic),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!),
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
    await tester.scrollUntilVisible(find.text('Submit report'), 150,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not send'), findsOneWidget);
    expect(find.text('Wrong word in the response'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Submit report'), 150,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(find.text('Submit report'), 150,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(sent, isNull);
    expect(find.text('Enter a title'), findsOneWidget);
    expect(find.text('Describe the error'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'Settings issue');
    await tester.enterText(
        find.byType(TextFormField).last, 'The control does not respond');
    await tester.scrollUntilVisible(find.text('Submit report'), 150,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(sent?['kind'], 'general');
    expect(sent?['number'], 0);
    expect(sent?['edition'], '');
  });
  testWidgets('translated reporting preserves source text on failure and retry',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final attempts = <Map<String, dynamic>>[];
          await open(
              tester,
              const ErrorReportSubject(
                  title: 'Himnario Adventista · 230 · Abre tu corazón'),
              (report) async {
            attempts.add(report);
            if (attempts.length == 1) throw Exception('offline');
          }, locale: locale, classic: classic, dark: dark);
          final context = tester.element(find.byType(ReportErrorPage));
          final text = context.appText;
          await tester.scrollUntilVisible(find.text(text.submitReport), 150,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.submitReport));
          await tester.pumpAndSettle();
          expect(attempts, isEmpty);
          expect(find.text(text.reportDescription), findsWidgets);
          await tester.enterText(find.byType(TextFormField).last,
              'La palabra corazón está incompleta.');
          await tester.scrollUntilVisible(find.text(text.submitReport), 150,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.submitReport));
          await tester.pumpAndSettle();
          expect(find.text(text.reportSendError), findsOneWidget);
          expect(
              find.text('La palabra corazón está incompleta.'), findsOneWidget);
          await tester.scrollUntilVisible(find.text(text.submitReport), 150,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.submitReport));
          await tester.pumpAndSettle();
          expect(attempts, hasLength(2));
          expect(attempts.first['id'], attempts.last['id']);
          expect(attempts.last['kind'], 'general');
          expect(attempts.last['edition'], '');
          expect(attempts.last['item_id'], '');
          expect(attempts.last['number'], 0);
          expect(attempts.last['title'],
              'Himnario Adventista · 230 · Abre tu corazón');
          expect(attempts.last['description'],
              'La palabra corazón está incompleta.');
          expect(find.text(text.reportSubmitted), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });
}
