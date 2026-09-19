import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models.dart';
import 'cards.dart';
import '../controls/chips.dart';

/// "值得注意" card: a plain-language statement and the evidence behind it.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.insight,
    this.title = '值得注意',
    this.onTap,
  });

  final Insight insight;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.overline),
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
