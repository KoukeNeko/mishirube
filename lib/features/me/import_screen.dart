import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_store.dart';

import '../../app/theme.dart';
import '../../backend/import_export/export_files.dart';
import '../../backend/backend.dart';
import '../../shared/widgets/widgets.dart';

const _issues = [
  (61, '找不到對應的動作', '會建立為自訂動作'),
  (22, '單位是磅', '會換算成公斤並保留原值'),
  (11, '日期格式無法解析', '不會匯入，會列在報告裡'),
];

/// Dry-run report for importing a Strong CSV export, plus export options.
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final issueCount = _issues.fold(0, (sum, issue) => sum + issue.$1);
    return DetailPage(
      appBar: const PageAppBar(title: '匯入 Strong 資料', subtitle: '試跑報告 · 尚未寫入'),
      footer: ButtonPair(
        secondary: SecondaryButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        primaryFlex: 2,
        primary: PrimaryButton(
          label: '確認匯入',
          onPressed: () {
            showToast(context, '已匯入 1,190 筆，可以整批復原', kind: ToastKind.success);
            Navigator.of(context).pop();
          },
        ),
      ),
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'strong_export_2026-09-18.csv',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                StatRow(
                  stats: [
                    const StatBlock(value: '1,284', label: '讀到'),
                    const StatBlock(value: '1,190', label: '可直接對應'),
                    StatBlock(
                      value: '$issueCount',
                      label: '需要處理',
                      valueColor: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Gutter(
          child: const InfoBanner(
            tone: CardTone.warning,
            message: '這是試跑，還沒有寫入任何資料。確認後可以整批復原。',
          ),
        ),
        Gutter(child: SectionLabel('需要處理的 $issueCount 筆')),
        for (final (count, title, detail) in _issues)
          Gutter(
            child: _IssueRow(count: count, title: title, detail: detail),
          ),
        Gutter(child: const SectionLabel('匯出')),
        Gutter(
          child: NavCard(
            title: '完整封存（JSON）',
            subtitle: '帶 schema 版本，可完整還原',
            onTap: () => _export(
              context,
              (backend) async =>
                  p.basename((await backend.writeArchive()).path),
              done: '已建立完整封存',
            ),
          ),
        ),
        Gutter(
          child: NavCard(
            title: 'CSV 檢視',
            subtitle: '方便閱讀，不保證無損',
            onTap: () => _export(
              context,
              (backend) async =>
                  p.basename((await backend.writeCsvViews()).path),
              done: '已建立 CSV 檢視',
            ),
          ),
        ),
      ],
    );
  }
}

/// Runs [write] and reports where the export went, or that it failed.
Future<void> _export(
  BuildContext context,
  Future<String> Function(Backend backend) write, {
  required String done,
}) async {
  final backend = AppStoreScope.read(context).backend;
  try {
    final name = await write(backend);
    if (!context.mounted) return;
    showToast(context, '$done：$name', kind: ToastKind.success);
  } on FileSystemException catch (error) {
    if (!context.mounted) return;
    showToast(context, '匯出失敗：${error.message}', kind: ToastKind.warning);
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.count,
    required this.title,
    required this.detail,
  });

  final int count;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$count',
              style: AppTextStyles.bigNumber.copyWith(fontSize: 26),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.itemTitle),
                Text(detail, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
