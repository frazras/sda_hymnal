import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_text.dart';
import '../services/service_presentation.dart';

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

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final text = context.appText;
    setState(() => _sharing = true);
    try {
      final html = widget.presentation
          .html(previousLabel: text.previousItem, nextLabel: text.nextItem);
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(Uint8List.fromList(utf8.encode(html)),
              mimeType: 'text/html')
        ],
        fileNameOverrides: ['service-slides.html'],
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

  @override
  Widget build(BuildContext context) {
    final slide = widget.presentation.slides[_index];
    return Scaffold(
      appBar: AppBar(title: Text(widget.presentation.name), actions: [
        Builder(
            builder: (context) => IconButton(
                tooltip: context.appText.sharePresentation,
                icon: const Icon(Icons.share_outlined),
                onPressed: _sharing ? null : () => _share(context))),
      ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          color: const Color(0xff101510),
          child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text(slide.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SelectableText(slide.text,
                    key: const ValueKey('presentation-slide-text'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26, height: 1.3)),
                const SizedBox(height: 20),
                Text(
                    '${slide.bookLabel}${slide.role == null ? '' : ' · ${slide.role}'}',
                    style: const TextStyle(
                        color: Color(0xffbec9be), fontSize: 14)),
              ])),
        )),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                IconButton(
                    tooltip: context.appText.previousItem,
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _index == 0 ? null : () => setState(() => _index--)),
                Text('${_index + 1} / ${widget.presentation.slides.length}'),
                IconButton(
                    tooltip: context.appText.nextItem,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _index == widget.presentation.slides.length - 1
                        ? null
                        : () => setState(() => _index++)),
              ],
            )),
      ])),
    );
  }
}
