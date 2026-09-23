import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_store.dart';
import '../../backend/backend.dart';
import '../../backend/import_export/export_files.dart';
import '../../shared/widgets/widgets.dart';

/// Writing the user's records out of the app.
///
/// Importing has a working dry run and commit underneath, but no way yet
/// to pick a file, so it is not offered here: a report of an import
/// that never ran would be the one screen in the app that lies about
/// the user's own data.
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '匯出'),
      children: [
        Gutter(
          child: NavCard(
            title: '完整封存（JSON）',
            subtitle: '可完整還原',
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
        Gutter(
          child: const InfoBanner(
            message:
                '匯出的檔案沒有加密。它就是你的健康紀錄，存到哪裡就和那裡一樣私密。'
                'API 金鑰之類的祕密不會寫進去。',
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
