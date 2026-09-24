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
    final facts = _report.facts;
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
    final summary = await AppStoreScope.read(context).summarizeTrends(facts);
    if (!mounted || _summarized != facts) return;
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final facts = report.facts;
    final changes = [
      if (report.findings.isNotEmpty)
        PageSection(
          label: '值得注意',
          children: [
            for (final (:domain, :insight) in report.findings)
              Gutter(
                child: InsightCard(insight: insight, title: domain.label),
              ),
          ],
        ),
      if (report.relation case final relation?)
        PageSection(
          label: '可能的關聯',
          children: [
            Gutter(
              child: InsightCard(insight: relation, title: '睡眠與訓練'),
            ),
          ],
        ),
    ];
    final lines = report.lines.isEmpty
        ? null
        : PageSection(
            label: '長期走向',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final line in report.lines)
                      _LineRow(
                        line: line,
                        onTap: () => pushPage(context, _pageFor(line.domain)),
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
          subtitle: '近 4 週與前 4 週',
          children: [
            if (report.lines.isEmpty)
              Gutter(child: const InfoBanner(message: '紀錄還不夠多。')),
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
          TagWrap(labels: ['Apple Intelligence 整理', '依據 $factCount 項紀錄']),
        ],
      ),
    );
  }
}

/// An area where it stands, against the stretch before, and its weeks.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.onTap});

  static const _chartWidth = 64.0;

  final TrendLine line;
  final VoidCallback onTap;

  Color get _color => switch (line.domain) {
    TrendDomain.body => AppColors.body,
    TrendDomain.training => AppColors.training,
    TrendDomain.sleep => AppColors.wellness,
    TrendDomain.nutrition => AppColors.nutrition,
    TrendDomain.activity => AppColors.activity,
  };

  @override
  Widget build(BuildContext context) {
    return NavRow(
      leading: AccentBar(color: _color, height: 28),
      title: line.domain.label,
      subtitle: line.value,
      detail: line.change,
      trailing: line.weekly.length < 2
          ? null
          : SizedBox(
              width: _chartWidth,
              child: ExcludeSemantics(
                child: Sparkline(
                  values: line.weekly,
                  color: _color,
                  height: 28,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}
