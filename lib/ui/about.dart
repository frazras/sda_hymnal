import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

/// About Us sub-page (mockups/About v2.dc.html).
///
/// Pinned 56px sub-page header, then a scrolling region with the photo card,
/// name row + role badge, bio paragraph, and the contact info card.
class About extends StatelessWidget {
  const About({super.key});

  static final Uri _twitterUrl = Uri.parse('https://twitter.com/frazras');
  static final Uri _emailUrl = Uri(scheme: 'mailto', path: 'rohan@exterbox.com');

  /// Google Play requires a privacy policy link inside the app itself, not
  /// only in the Play Console listing field.
  static final Uri _privacyUrl =
      Uri.parse('https://frazras.github.io/sda_hymnal/privacy-policy.html');

  static const String _bio =
      'I am a software developer for Mobile Apps and Websites. This project '
      'is my contribution to help you develop a closer relationship with the '
      'Lord. I pray you keep your heart pure and lift your praises high.';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'About Us'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo card: margin 20/20/0, radius 20, 330px cover,
                    // focus 20% from the top (object-position 50% 20%).
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/rohan.jpg',
                          height: 330,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.6),
                        ),
                      ),
                    ),
                    // Name row: padding 18/24/0, gap 10.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Rohan A. Smith',
                              style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 23,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              color: t.tint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'APP DEVELOPER',
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: trackingEm(0.08, 11),
                                color: t.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bio paragraph: padding 10/24/0, Literata 16 / 1.65.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Text(
                        _bio,
                        style: TextStyle(
                          fontFamily: kSerif,
                          fontSize: 16,
                          height: 1.65,
                          color: t.ink,
                        ),
                      ),
                    ),
                    // Info card: margin 20/20/40, surface, line border,
                    // radius 16, card shadow.
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(color: t.line),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: t.cardShadow,
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Country',
                            divider: true,
                            value: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Jamaica',
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.ink,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Image.asset(
                                    'assets/flag.png',
                                    width: 24,
                                    height: 12,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _InfoRow(
                            label: 'Twitter',
                            divider: true,
                            value: _LinkValue(
                              text: '@frazras',
                              onTap: () => launchUrl(_twitterUrl,
                                  mode: LaunchMode.externalApplication),
                            ),
                          ),
                          _InfoRow(
                            label: 'Email',
                            divider: true,
                            value: _LinkValue(
                              text: 'rohan@exterbox.com',
                              onTap: () => launchUrl(_emailUrl),
                            ),
                          ),
                          _InfoRow(
                            label: 'Privacy',
                            divider: false,
                            value: _LinkValue(
                              text: 'Privacy Policy',
                              onTap: () => launchUrl(_privacyUrl,
                                  mode: LaunchMode.externalApplication),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One info-card row: 13px muted label on the left, value on the right,
/// padding 14x16, optional hairline `line2` bottom divider.
class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final bool divider;

  const _InfoRow(
      {required this.label, required this.value, required this.divider});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line2)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                color: t.muted,
              ),
            ),
          ),
          value,
        ],
      ),
    );
  }
}

/// Accent link value (Twitter / Email). The mockup's only interactive styling
/// is the CSS hover shift accent -> accentHi; mapped here to the pressed
/// state, with no scale and no ripple.
class _LinkValue extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LinkValue({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Pressable(
      onTap: onTap,
      pressedScale: 1.0,
      builder: (context, pressed) => Text(
        text,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: pressed ? t.accentHi : t.accent,
        ),
      ),
    );
  }
}
