import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/domain.dart';
import 'cards.dart';
import '../controls/chips.dart';
import '../../../l10n/l10n.dart';

/// A card stating one finding in plain language, and the evidence behind
/// it; titled 值得注意 unless given a title.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight, this.title, this.onTap});

  final Insight insight;
  final String? title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? context.l10n.insightCardTitle,
            style: AppTextStyles.overline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.statement,
            style: AppTextStyles.body.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.md),
          TagWrap(labels: insight.evidence),
        ],
      ),
    );
  }
}
