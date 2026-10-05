import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app/app_store.dart';
import '../../backend/backend.dart';
import '../../backend/import_export/export_files.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// Writing the user's records out of the app, and handing them to the
/// system's share sheet: on Android the exports folder is the app's own,
/// which nobody can open, so the sheet is how the file leaves (to Files,
/// a drive, a mail), and on iOS it is the same way to take it from the
/// app.
///
/// Importing has a working dry run and commit underneath, but no way yet
/// to pick a file, so it is not offered here: a report of an import
/// that never ran would be the one screen in the app that lies about
/// the user's own data.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isWriting = false;

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(title: context.l10n.exportTitle),
      children: [
        Gutter(
          child: NavCard(
            title: context.l10n.fullArchiveJson,
            subtitle: context.l10n.fullArchiveDetail,
            onTap: _isWriting
                ? null
                : () => _export(
                    (backend) async => [(await backend.writeArchive())],
                    done: context.l10n.fullArchiveDone,
                  ),
          ),
        ),
        Gutter(
          child: NavCard(
            title: context.l10n.csvViews,
            subtitle: context.l10n.csvViewsDetail,
            onTap: _isWriting
                ? null
                : () => _export(
                    (backend) async => [
                      for (final entry
                          in (await backend.writeCsvViews()).listSync())
                        if (entry is File) entry,
                    ],
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

  /// Runs [write], then offers what it wrote to the share sheet; when the
  /// sheet cannot open, says where the files are, or that it failed.
  Future<void> _export(
    Future<List<File>> Function(Backend backend) write, {
    required String done,
  }) async {
    final backend = AppStoreScope.read(context).backend;
    final size = MediaQuery.sizeOf(context);
    setState(() => _isWriting = true);
    try {
      final files = await write(backend);
      if (!mounted) return;
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [for (final file in files) XFile(file.path)],
            // An iPad anchors its sheet to something: here, the middle.
            sharePositionOrigin: Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: 1,
              height: 1,
            ),
          ),
        );
      } on Exception {
        if (!mounted) return;
        showToast(
          context,
          context.l10n.exportDoneFile(
            done: done,
            file: p.basename(
              files.length == 1 ? files.first.path : files.first.parent.path,
            ),
          ),
          kind: ToastKind.success,
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      showToast(
        context,
        context.l10n.exportFailed(
          error: error is FileSystemException ? error.message : '$error',
        ),
        kind: ToastKind.warning,
      );
    } finally {
      if (mounted) setState(() => _isWriting = false);
    }
  }
}
