import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

/// Donate sub-page (mockups/Donate v2.dc.html), pushed from Settings.
class Donate extends StatelessWidget {
  const Donate({super.key});

  static final Uri _donateUrl = Uri.parse('http://bit.ly/1PAZqQ2');

  Future<void> _launchDonate() async {
    await launchUrl(_donateUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Donate'),
            Expanded(
              // The CTA block lives inside the scroller and is pushed to the
              // bottom by a flex spacer: pinned on tall screens, scrolls with
              // content on short ones (mockup behavior, not a fixed footer).
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Image card: margin 20/20/0, radius 20, 190 cover.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/donate.jpg',
                                width: double.infinity,
                                height: 190,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Headline
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Text(
                              'Every dollar is appreciated',
                              style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: t.ink,
                              ),
                            ),
                          ),
                          // Paragraph
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Text(
                              'Writing software is hard work! It takes a lot '
                              'of time to develop and maintain good software. '
                              'I made this app free so that all can access '
                              'the benefits in spite of your means. If this '
                              'app has brought you joy and you would like to '
                              'support the development of more features, '
                              'please give below.',
                              style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 16,
                                height: 1.65,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // CTA block: padding 20/20/28, gap 10.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Pressable(
                                  onTap: _launchDonate,
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
                                      'Donate',
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
                                  'Opens a secure page in your browser',
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
