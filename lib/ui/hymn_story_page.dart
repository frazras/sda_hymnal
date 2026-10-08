import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

class HymnStoryPage extends StatelessWidget {
  final Hymn hymn;

  const HymnStoryPage({super.key, required this.hymn});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final metadata = hymn.metadata!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(title: context.appText.hymnStory),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          metadata.title,
                          style: TextStyle(
                            fontFamily: kSerif,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${hymn.bookLabel} #${hymn.number}',
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        for (var index = 0;
                            index < metadata.stories.length;
                            index++) ...[
                          _StoryCard(
                            story: metadata.stories[index],
                          ),
                          if (index + 1 < metadata.stories.length)
                            const SizedBox(height: 16),
                        ],
                      ],
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

class _StoryCard extends StatelessWidget {
  final HymnStory story;

  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.sourceName,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.accent,
            ),
          ),
          if (story.hasText) ...[
            const SizedBox(height: 12),
            SelectableText(
              story.text!,
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 17,
                height: 1.65,
                color: t.ink,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              context.appText.storyPublisherHelp,
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 16,
                height: 1.5,
                color: t.ink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
