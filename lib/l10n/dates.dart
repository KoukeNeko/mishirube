import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

/// Dates in the app's language, in its own word order and weekday names.
///
/// Chinese keeps the app's own spaced form, `9 月 27 日（週六）`; the others
/// take their locale's pattern (`Sat, Sep 27`, `9月27日(土)`, `9월 27일 (토)`).
/// Date symbols are loaded by the Material localizations the app installs.
class AppDates {
  AppDates(Locale locale) : _locale = _intlLocale(locale) {
    _loadSymbols();
  }

  /// For code without a widget tree, in [l10n]'s language. The plain `zh`
  /// strings are the Traditional ones.
  AppDates.of(AppLocalizations l10n)
    : _locale = switch (l10n.localeName) {
        'zh_Hans' => 'zh',
        final name when name.startsWith('zh') => 'zh_TW',
        final name => name,
      } {
    _loadSymbols();
  }

  static var _symbolsLoaded = false;

  /// The date names of every locale, bundled with intl. Formatting can come
  /// before any screen loads its localizations (a log row built at
  /// launch), so it does not wait for them. The bundled data loads at once;
  /// the future only reports it.
  static void _loadSymbols() {
    if (_symbolsLoaded) return;
    _symbolsLoaded = true;
    initializeDateFormatting();
  }

  final String _locale;

  static String _intlLocale(Locale locale) =>
      switch ((locale.languageCode, locale.scriptCode, locale.countryCode)) {
        ('zh', 'Hans', _) || ('zh', null, 'CN') => 'zh',
        ('zh', _, _) => 'zh_TW',
        (final language, _, _) => language,
      };

  bool get _isChinese => _locale.startsWith('zh');

  /// A Monday, for naming weekdays by number.
  static final _monday = DateTime(2024, 1, 1);

  // l10n-ignore-start: the patterns Chinese dates are written in; intl's
  // own run the parts together without the spaces the app's copy uses.

  /// `9 月 27 日（週六）`, `Sat, Sep 27`.
  String dayWithWeekday(DateTime day) =>
      (_isChinese
              ? DateFormat('M 月 d 日（EEE）', _locale)
              : DateFormat.MMMEd(_locale))
          .format(day);

  /// `9 月 27 日`, `Sep 27`.
  String monthDay(DateTime day) =>
      (_isChinese ? DateFormat('M 月 d 日', _locale) : DateFormat.MMMd(_locale))
          .format(day);

  /// `2026 年 9 月 21 日`, `Sep 21, 2026`.
  String fullDate(DateTime day) =>
      (_isChinese
              ? DateFormat('y 年 M 月 d 日', _locale)
              : DateFormat.yMMMd(_locale))
          .format(day);

  /// `2026/9/21`, `9/21/2026`.
  String date(DateTime day) => DateFormat.yMd(_locale).format(day);

  /// `2026 年`, `2026`.
  String year(int year) =>
      (_isChinese ? DateFormat('y 年', _locale) : DateFormat.y(_locale)).format(
        DateTime(year),
      );

  /// `9 月`, `Sep`.
  String month(int month) =>
      (_isChinese ? DateFormat('M 月', _locale) : DateFormat.MMM(_locale))
          .format(DateTime(2024, month));

  /// `2026 年 9 月`, `September 2026`.
  String yearMonth(DateTime month) =>
      (_isChinese ? DateFormat('y 年 M 月', _locale) : DateFormat.yMMMM(_locale))
          .format(month);

  /// `9月`, `Sep`: a month as the system writes it, unspaced.
  String compactMonth(DateTime month) =>
      (_isChinese ? DateFormat('M月', _locale) : DateFormat.MMM(_locale)).format(
        month,
      );

  /// `2026年`, `2026`.
  String compactYear(int year) =>
      (_isChinese ? DateFormat('y年', _locale) : DateFormat.y(_locale)).format(
        DateTime(year),
      );

  /// `2026年1月`, `Jan 2026`.
  String compactYearMonth(DateTime month) =>
      (_isChinese ? DateFormat('y年M月', _locale) : DateFormat.yMMM(_locale))
          .format(month);

  /// `9月27日`, `Sep 27`.
  String compactMonthDay(DateTime day) =>
      (_isChinese ? DateFormat('M月d日', _locale) : DateFormat.MMMd(_locale))
          .format(day);

  /// `9月27日 週六`, `Sat, Sep 27`.
  String compactDayWithWeekday(DateTime day) =>
      (_isChinese ? DateFormat('M月d日 EEE', _locale) : DateFormat.MMMEd(_locale))
          .format(day);

  /// The weekday of [day], short: `六`, `Sat`, `土`.
  String weekday(DateTime day) =>
      (_isChinese ? DateFormat('EEEEE', _locale) : DateFormat.E(_locale))
          .format(day);
  // l10n-ignore-end

  /// The weekday of [day] in full, for a screen reader: `星期六`,
  /// `Saturday`.
  String weekdayName(DateTime day) => DateFormat.EEEE(_locale).format(day);

  /// [weekday] (1 is Monday), short, as [weekday] writes it.
  String weekdayNumber(int weekday) =>
      this.weekday(_monday.add(Duration(days: weekday - 1)));

  /// [weekday] (1 is Monday) in full, as [weekdayName] writes it.
  String weekdayNumberName(int weekday) =>
      weekdayName(_monday.add(Duration(days: weekday - 1)));
}

extension AppDatesContext on BuildContext {
  AppDates get dates => AppDates(Localizations.localeOf(this));
}
