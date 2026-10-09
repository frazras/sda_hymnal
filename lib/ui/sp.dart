import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

/// "Our Other Projects" sub-page (mockup: Other Projects v2.dc.html).
///
/// Pushed full-screen with [slideRoute]; no brand header, no bottom nav.
/// White logo card (pure #FFFFFF even in dark mode), serif title + paragraph,
/// and a bottom-pinned CTA that scrolls with content on short screens.
class Sp extends StatelessWidget {
  const Sp({super.key});

  static final Uri _siteUri = Uri.parse('https://sabbathprograms.com/weekly');

  Future<void> _openWebsite() async {
    await launchUrl(_siteUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(title: context.appText.otherProjects),
            Expanded(
              // Flex-1 spacer bottom-pins the CTA on tall screens; on short
              // screens the whole column scrolls (CTA is not a fixed overlay).
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo card: hard-coded white in BOTH themes;
                          // border stays the themed `line` token.
                          Container(
                            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Image.asset(
                              'assets/sp.png',
                              width: double.infinity,
                              height: 170,
                              fit: BoxFit.contain,
                              semanticLabel: 'Sabbath Programs',
                            ),
                          ),
                          // Title
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Text(
                              'SabbathPrograms.com',
                              style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 23,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                          ),
                          // Body paragraph
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Text(
                              context.appText.sabbathProgramsDescription,
                              style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.65,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                          // CTA block
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Pressable(
                                  onTap: _openWebsite,
                                  pressedScale: 0.98,
                                  builder: (context, pressed) => Container(
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: t.accent,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: t.ctaShadow,
                                    ),
                                    child: Text(
                                      context.appText.visitWebsite,
                                      style: TextStyle(
                                        fontFamily: kSans,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: t.onAccent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'sabbathprograms.com/weekly',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 12,
                                    color: t.faint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
