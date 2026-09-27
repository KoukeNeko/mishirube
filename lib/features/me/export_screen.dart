import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_store.dart';
import '../../backend/backend.dart';
import '../../backend/import_export/export_files.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

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
      appBar: PageAppBar(title: context.l10n.exportTitle),
      children: [
        Gutter(
          child: NavCard(
            title: context.l10n.fullArchiveJson,
            subtitle: context.l10n.fullArchiveDetail,
            onTap: () => _export(
              context,
              (backend) async =>
                  p.basename((await backend.writeArchive()).path),
              done: context.l10n.fullArchiveDone,
            ),
          ),
        ),
        Gutter(
          child: NavCard(
            title: context.l10n.csvViews,
            subtitle: context.l10n.csvViewsDetail,
            onTap: () => _export(
              context,
              (backend) async =>
                  p.basename((await backend.writeCsvViews()).path),
              done: context.l10n.csvViewsDone,
            ),
          ),
        ),
        Gutter(
          child: InfoBanner(
            tone: CardTone.warning,
            message: context.l10n.exportNotEncrypted,
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
    showToast(
      context,
      context.l10n.exportDoneFile(done: done, file: name),
      kind: ToastKind.success,
    );
  } on FileSystemException catch (error) {
    if (!context.mounted) return;
    showToast(
      context,
      context.l10n.exportFailed(error: error.message),
      kind: ToastKind.warning,
    );
  }
}
