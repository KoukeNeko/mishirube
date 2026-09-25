import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/insights_service.dart';
import '../../backend/engines/trend_findings.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/daily_activity_screen.dart';
import '../body/body_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../sleep/sleep_screen.dart';
import 'training_trends_screen.dart';
import 'trends_view_model.dart';

/// What changed over the last weeks, across every area (see
/// `research/51-trends.md`): the changes worth noticing, a relation when
/// the records support one, and each area's long-run line, which opens
/// that area. The engine decides what is said and over what stretch;
/// with Apple Intelligence on, the on-device model puts the same facts
/// into a few sentences, and adds nothing to them.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  late final _model = TrendsViewModel(AppStoreScope.read(context).backend)
    ..addListener(_reload);

  late TrendsReport _report;

  /// The summary, and the provider and facts it was asked for with, so
  /// it is asked for again only when either changes.
  List<String>? _summarized;
  AiProviderKind? _summarizedBy;
  String? _summary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depending on the store: Apple Intelligence may turn out to be
    // available only after the page is first built.
    AppStoreScope.of(context);
    _reload(rebuild: false);
  }

  @override
  void dispose() {
    _model
      ..removeListener(_reload)
      ..dispose();
    super.dispose();
  }

  void _reload({bool rebuild = true}) {
    _report = _model.report;
    final facts = _report.isWorthSummarizing ? _report.facts : const <String>[];
    final provider = AppStoreScope.read(context).aiProvider;
    if (_summarized == null ||
        _summarizedBy != provider ||
        !_sameFacts(_summarized!, facts)) {
      _summary = null;
      _summarizedBy = provider;
      _summarize(facts);
    }
    if (rebuild) setState(() {});
  }

  Future<void> _summarize(List<String> facts) async {
    _summarized = facts;
    if (facts.isEmpty) return;
    final summary = await AppStoreScope.read(context).summarizeTrends(facts);
    if (!mounted || _summarized != facts) return;
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final facts = report.facts;
    final modules = AppStoreScope.of(context).enabledModules;
    final linesByDomain = {for (final line in report.lines) line.domain: line};
    final changes = [
      if (report.findings.isNotEmpty)
        PageSection(
          label: '值得注意',
          children: [
            for (final finding in report.findings)
              Gutter(
                child: _FindingCard(
                  finding: finding,
                  onTap: () => pushPage(context, _pageFor(finding.domain)),
                ),
              ),
          ],
        ),
      if (report.relation case final relation?)
        PageSection(
          label: '可能的關聯',
          children: [Gutter(child: _RelationCard(relation: relation))],
        ),
    ];
    // Every area the app logs gets a row, with or without records yet,
    // so each area's page is always one tap away.
    final domains = [
      for (final domain in TrendDomain.values)
        if (modules.contains(_moduleOf(domain))) domain,
    ];
    final lines = domains.isEmpty
        ? null
        : PageSection(
            label: '長期走向',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final domain in domains)
                      _LineRow(
                        domain: domain,
                        line: linesByDomain[domain],
                        onTap: () => pushPage(context, _pageFor(domain)),
                      ),
                  ],
                ),
              ),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        // With room for two columns, the changes and the long run sit
        // side by side instead of one long page.
        final isWide =
            changes.isNotEmpty &&
            lines != null &&
            constraints.maxWidth >= _minColumnWidth * 2;
        return CollapsingPage(
          title: '趨勢',
          children: [
            if (_summary case final summary?)
              Gutter(
                child: _SummaryCard(summary: summary, factCount: facts.length),
              ),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(spacing: pageItemSpacing, children: changes),
                  ),
                  Expanded(child: lines),
                ],
              )
            else ...[
              ...changes,
              ?lines,
            ],
          ],
        );
      },
    );
  }

  /// Narrowest a column reads well at, gutters included.
  static const _minColumnWidth = 380.0;

  static bool _sameFacts(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  static AppModule _moduleOf(TrendDomain domain) => switch (domain) {
    TrendDomain.body => AppModule.weight,
    TrendDomain.training => AppModule.training,
    TrendDomain.sleep => AppModule.sleep,
    TrendDomain.nutrition => AppModule.nutrition,
    TrendDomain.activity => AppModule.activity,
  };

  static Widget _pageFor(TrendDomain domain) => switch (domain) {
    TrendDomain.body => const BodyScreen(),
    TrendDomain.training => const TrainingTrendsScreen(),
    TrendDomain.sleep => const SleepScreen(),
    TrendDomain.nutrition => const DailyNutritionScreen(),
    TrendDomain.activity => const DailyActivityScreen(),
  };
}

/// The on-device model's wording of the facts on this page.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.factCount});

  final String summary;
  final int factCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  'Apple Intelligence 整理 · 依據 $factCount 項紀錄',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _colorOf(TrendDomain domain) => switch (domain) {
  TrendDomain.body => AppColors.body,
  TrendDomain.training => AppColors.training,
  TrendDomain.sleep => AppColors.wellness,
  TrendDomain.nutrition => AppColors.nutrition,
  TrendDomain.activity => AppColors.activity,
};

/// A change worth noticing: what moved, where it stands and by how
/// much, its weeks, and what it rests on. Opens the area it is about.
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding, required this.onTap});

  final TrendFinding finding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(finding.domain);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryLabel(label: finding.domain.label, color: color),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(finding.headline, style: AppTextStyles.itemTitle),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(finding.value, style: AppTextStyles.bigNumber),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(finding.change, style: AppTextStyles.body),
              ),
            ],
          ),
          if (finding.weekly.length >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            ExcludeSemantics(
              child: Sparkline(
                values: finding.weekly,
                color: color,
                height: 40,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            [finding.comparison, ...finding.insight.evidence].join(' · '),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// A relation between two areas, with what it rests on, and never more
/// than a relation.
class _RelationCard extends StatelessWidget {
  const _RelationCard({required this.relation});

  final Insight relation;

  @override
  Widget build(BuildContext context) {
    const caveat = '關聯，不代表因果';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryLabel(
                label: TrendDomain.sleep.label,
                color: _colorOf(TrendDomain.sleep),
              ),
              const SizedBox(width: AppSpacing.sm),
              CategoryLabel(
                label: TrendDomain.training.label,
                color: _colorOf(TrendDomain.training),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(relation.statement, style: AppTextStyles.itemTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            [
              for (final line in relation.evidence)
                if (line != caveat) line,
            ].join(' · '),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          const TagChip(label: caveat),
        ],
      ),
    );
  }
}

/// An area where it stands, against the stretch before, and its weeks;
/// 沒有紀錄 until it has any.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.domain, this.line, required this.onTap});

  static const _chartWidth = 64.0;

  final TrendDomain domain;
  final TrendLine? line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final line = this.line;
    final color = _colorOf(domain);
    return NavRow(
      leading: AccentBar(color: color, height: 28),
      title: domain.label,
      subtitle: line?.value ?? '沒有紀錄',
      detail: line?.change,
      trailing: line == null || line.weekly.length < 2
          ? null
          : SizedBox(
              width: _chartWidth,
              child: ExcludeSemantics(
                child: Sparkline(values: line.weekly, color: color, height: 28),
              ),
            ),
      onTap: onTap,
    );
  }
}
