import '../backend/storage/database.dart';
import '../l10n/l10n.dart';

/// Where a record came from, in the words the screens show.
String changeSourceLabel(AppLocalizations l10n, ChangeSource? source) =>
    switch (source) {
      ChangeSource.local => l10n.sourceManual,
      ChangeSource.seed => l10n.sourceDemo,
      ChangeSource.strongImport ||
      ChangeSource.archiveImport => l10n.sourceImport,
      ChangeSource.aiDraft => l10n.sourceAiDraft,
      ChangeSource.catalogue => l10n.sourceCatalogue,
      ChangeSource.healthKit => l10n.sourceAppleHealth,
      // A product name, the same in every language.
      ChangeSource.healthConnect => 'Health Connect',
      null => l10n.sourceUnknown,
    };
