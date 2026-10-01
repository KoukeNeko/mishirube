import '../../l10n/l10n.dart';

/// How far back a body chart reaches.
enum BodyRange {
  month(Duration(days: 30)),
  quarter(Duration(days: 90)),
  year(Duration(days: 365));

  const BodyRange(this.window);

  final Duration window;

  String labelIn(AppLocalizations l10n) => switch (this) {
    month => l10n.chartRangeMonth,
    quarter => l10n.monthsCount(count: 3),
    year => l10n.yearsCount(count: 1),
  };
}
