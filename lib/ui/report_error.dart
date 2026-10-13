import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import '../services/analytics_store.dart' show analyticsId;
import '../services/error_reports.dart';
import '../theme.dart';
import 'common.dart';
import 'kit.dart';

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
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: !_sending,
      child: HymnalPage(
        title: context.appText.reportErrors,
        body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                if (widget.subject.kind != 'general') ...[
                  HymnalCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            context.appText.reportSubject(
                                widget.subject.bookLabel.isNotEmpty
                                    ? widget.subject.bookLabel
                                    : switch (widget.subject.edition) {
                                        'old' => context.appText.oldHymnal,
                                        'new' => context.appText.newHymnal,
                                        _ => widget.subject.edition,
                                      },
                                widget.subject.kind == 'reading'
                                    ? context.appText.reading
                                    : context.appText.hymnLabel,
                                widget.subject.number),
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: t.ink)),
                        TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft),
                          onPressed: _sending
                              ? null
                              : () => Navigator.push(
                                    context,
                                    slideRoute(
                                        ReportErrorPage(submit: widget.submit)),
                                  ),
                          child: Text(context.appText.reportGeneralInstead),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                TextFormField(
                    controller: _title,
                    enabled: !_sending,
                    maxLength: 200,
                    decoration: InputDecoration(
                        labelText: context.appText.reportTitle,
                        hintText: context.appText.reportTitleHint),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.appText.reportTitleRequired
                        : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _description,
                    enabled: !_sending,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 5000,
                    decoration: InputDecoration(
                        alignLabelWithHint: true,
                        labelText: context.appText.reportDescription,
                        hintText: context.appText.reportDescriptionHint),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.appText.reportDescription
                        : null),
                const SizedBox(height: 8),
                Text(context.appText.reportPrivacyHelp,
                    style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12.5,
                        height: 1.4,
                        color: t.muted)),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!,
                          style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.error))),
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
}
