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
        const SnackBar(
            content: Text('Thank you. Your error report has been submitted.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error =
              'Could not send your report. Check your connection and try again. Your text is still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sending,
        child: Scaffold(
          appBar: AppBar(title: const Text('Report Errors')),
          body: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (widget.subject.kind != 'general') ...[
                    Text(
                        '${widget.subject.edition == 'old' ? 'Old' : 'New'} hymnal · ${widget.subject.kind} ${widget.subject.number}'),
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
                        child: const Text('Report a general app issue instead'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                      controller: _title,
                      enabled: !_sending,
                      maxLength: 200,
                      decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'What is the error about?'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a title'
                              : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _description,
                      enabled: !_sending,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                          labelText: 'Describe the error',
                          hintText:
                              'Tell us what is wrong and, if possible, what it should say.'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Describe the error'
                              : null),
                  const SizedBox(height: 12),
                  const Text(
                      'Your report will be sent to the app administrators. Please do not include personal or sensitive information.'),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!)),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _sending ? null : _send,
                      child: Text(_sending ? 'Sending…' : 'Submit report')),
                ],
              )),
        ),
      );
}
