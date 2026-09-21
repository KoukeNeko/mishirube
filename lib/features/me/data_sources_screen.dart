import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// Where the records in this app came from.
///
/// Source and permission are different questions; this page answers the
/// first. Only sources that exist are listed: an integration the app
/// does not have yet would be a row that leads nowhere.
class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final typed = store.typedRecordCounts;
    final demo = store.demoRecordCounts;
    final imports = store.imports;
    final catalogues = store.catalogues;
    return DetailPage(
      appBar: const PageAppBar(title: '資料來源', subtitle: '每筆紀錄都記得它從哪裡來'),
      children: [
        Gutter(child: const SectionLabel('你輸入的')),
        Gutter(
          child: _Counts(counts: typed, empty: '還沒有自己輸入的紀錄。'),
        ),
        if (demo.isNotEmpty) ...[
          Gutter(child: const SectionLabel('示範資料')),
          Gutter(
            child: _Counts(counts: demo, empty: ''),
          ),
          Gutter(
            child: const Text(
              '第一次開啟時放進來的範例，讓畫面不是空的。它們不是你的紀錄。',
              style: AppTextStyles.caption,
            ),
          ),
        ],
        Gutter(child: const SectionLabel('匯入')),
        if (imports.isEmpty)
          Gutter(child: const Text('還沒有匯入過任何檔案。', style: AppTextStyles.caption))
        else
          Gutter(
            child: GroupedCard(
              children: [
                for (final record in imports)
                  KeyValueRow(
                    label: record.fileName ?? record.source,
                    value: record.isUndone
                        ? '已復原'
                        : '${record.records} 筆 · '
                              '${formatDate(record.importedAt)}',
                  ),
              ],
            ),
          ),
        if (catalogues.isNotEmpty) ...[
          Gutter(child: const SectionLabel('內建目錄')),
          Gutter(
            child: GroupedCard(
              children: [
                for (final catalogue in catalogues)
                  KeyValueRow(
                    label: catalogue.brand,
                    value:
                        '${catalogue.products} 款 · '
                        '${catalogue.sizes} 種杯型',
                  ),
              ],
            ),
          ),
          Gutter(
            child: Text(
              [
                '依品牌官網逐筆轉錄，唯讀，不能修改；App 更新時會整批替換。',
                for (final catalogue in catalogues)
                  if (catalogue.checkedAt case final at?)
                    '${catalogue.brand}查證於 ${formatDate(at)}。',
              ].join(''),
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ],
    );
  }
}

/// Records per category, in the order categories are shown everywhere.
class _Counts extends StatelessWidget {
  const _Counts({required this.counts, required this.empty});

  final Map<RecordCategory, int> counts;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return Text(empty, style: AppTextStyles.caption);
    return GroupedCard(
      children: [
        for (final category in RecordCategory.values)
          if (counts[category] case final count?)
            KeyValueRow(label: category.label, value: '$count 筆'),
      ],
    );
  }
}
