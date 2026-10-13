import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_text.dart';
import '../services/service_presentation.dart';
import '../theme.dart';
import 'kit.dart';

class ServicePresentationPage extends StatefulWidget {
  const ServicePresentationPage({super.key, required this.presentation});
  final ServicePresentation presentation;
  @override
  State<ServicePresentationPage> createState() =>
      _ServicePresentationPageState();
}

class _ServicePresentationPageState extends State<ServicePresentationPage> {
  int _index = 0;
  bool _sharing = false;

  Future<void> _chooseShare(BuildContext buttonContext) async {
    final format = await showHymnalSheet<String>(
      context,
      title: context.appText.sharePresentation,
      builder: (sheet) => Column(children: [
        SheetOption(
          key: const ValueKey('share-html'),
          leading: const RowIcon(Icons.slideshow_outlined),
          title: sheet.appText.shareSlidesHtml,
          subtitle: sheet.appText.shareSlidesHtmlHelp,
          onTap: () => Navigator.pop(sheet, 'html'),
        ),
        SheetOption(
          key: const ValueKey('share-videopsalm'),
          leading: const RowIcon(Icons.video_library_outlined),
          title: sheet.appText.shareVideoPsalm,
          subtitle: sheet.appText.shareVideoPsalmHelp,
          divider: false,
          onTap: () => Navigator.pop(sheet, 'vpc'),
        ),
      ]),
    );
    if (format == null || !mounted || !buttonContext.mounted) return;
    await _share(buttonContext, videoPsalm: format == 'vpc');
  }

  Future<void> _share(BuildContext buttonContext,
      {bool videoPsalm = false}) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final text = context.appText;
    setState(() => _sharing = true);
    try {
      final XFile file;
      final String filename;
      if (videoPsalm) {
        file = XFile.fromData(
            Uint8List.fromList(widget.presentation
                .videoPsalmPackage(roleLabel: text.readingRoleLabel)),
            mimeType: 'application/octet-stream');
        filename = '${exportFileStem(widget.presentation.name)}.vpc';
      } else {
        final html = widget.presentation.html(
            previousLabel: text.previousItem,
            nextLabel: text.nextItem,
            roleLabel: text.readingRoleLabel);
        file = XFile.fromData(Uint8List.fromList(utf8.encode(html)),
            mimeType: 'text/html');
        filename = 'service-slides.html';
      }
      await SharePlus.instance.share(ShareParams(
        files: [file],
        fileNameOverrides: [filename],
        subject: widget.presentation.name,
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(text.presentationExportFailed)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.presentation.slides.length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final slide = widget.presentation.slides[_index];
    return HymnalPage(
      title: widget.presentation.name,
      trailing: Builder(
          builder: (context) => HeaderAction(
              icon: Icons.ios_share,
              tooltip: context.appText.sharePresentation,
              onTap: _sharing ? null : () => _chooseShare(context))),
      body: Column(children: [
        Expanded(
            child: GestureDetector(
          // Swipe between slides, like turning hymn pages.
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -200) _go(1);
            if (velocity > 200) _go(-1);
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xff101510),
              borderRadius: BorderRadius.circular(t.isClassic ? 4 : 18),
            ),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text(slide.title,
                      style: const TextStyle(
                          fontFamily: kSerif,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  SelectableText(slide.text,
                      key: const ValueKey('presentation-slide-text'),
                      style: const TextStyle(
                          fontFamily: kSerif,
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.35)),
                  const SizedBox(height: 20),
                  Text(
                      '${slide.bookLabel}${slide.role == null ? '' : ' · ${context.appText.readingRoleLabel(slide.role!)}'}',
                      style: const TextStyle(
                          fontFamily: kSans,
                          color: Color(0xffbec9be),
                          fontSize: 13.5)),
                ])),
          ),
        )),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.6,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      tooltip: context.appText.previousItem,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _index == 0 ? null : () => _go(-1)),
                  SizedBox(
                    width: 72,
                    child: Text(
                        '${_index + 1} / ${widget.presentation.slides.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 13, color: t.muted)),
                  ),
                  IconButton(
                      tooltip: context.appText.nextItem,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _index == widget.presentation.slides.length - 1
                          ? null
                          : () => _go(1)),
                ],
              )),
        ),
      ]),
    );
  }
}
