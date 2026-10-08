import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import '../services/analytics_store.dart' show analyticsId;
import '../services/error_reports.dart';

class ReportErrorPage extends StatefulWidget {
  final ErrorReportSubject subject;
  final Future<void> Function(Map<String, dynamic>)? submit;
  const ReportErrorPage(
      {super.key, this.subject = const ErrorReportSubject(), this.submit});

  @override
  State<ReportErrorPage> createState() => _ReportErrorPageState();
}

class _ReportErrorPageState extends State<ReportErrorPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.subject.title);
  final _description = TextEditingController();
  final _id = analyticsId();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await (widget.submit ?? ErrorReports.submit)({
        ...widget.subject.toJson(),
        'id': _id,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.appText.reportSubmitted)),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = context.appText.reportSendError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sending,
        child: Scaffold(
          appBar: AppBar(title: Text(context.appText.reportErrors)),
          body: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (widget.subject.kind != 'general') ...[
                    Text(context.appText.reportSubject(
                        switch (widget.subject.edition) {
                          'old' => context.appText.oldHymnal,
                          'new' => context.appText.newHymnal,
                          _ => widget.subject.edition,
                        },
                        widget.subject.kind == 'reading'
                            ? context.appText.reading
                            : context.appText.hymnLabel,
                        widget.subject.number)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReportErrorPage(submit: widget.submit),
                                  ),
                                ),
                        child: Text(context.appText.reportGeneralInstead),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                      controller: _title,
                      enabled: !_sending,
                      maxLength: 200,
                      decoration: InputDecoration(
                          labelText: context.appText.reportTitle,
                          hintText: context.appText.reportTitleHint),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? context.appText.reportTitleRequired
                              : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _description,
                      enabled: !_sending,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 5000,
                      decoration: InputDecoration(
                          labelText: context.appText.reportDescription,
                          hintText: context.appText.reportDescriptionHint),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? context.appText.reportDescription
                              : null),
                  const SizedBox(height: 12),
                  Text(context.appText.reportPrivacyHelp),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!)),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _sending ? null : _send,
                      child: Text(_sending
                          ? context.appText.sendingReport
                          : context.appText.submitReport)),
                ],
              )),
        ),
      );
}
