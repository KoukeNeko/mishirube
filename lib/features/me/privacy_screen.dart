import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// What happens to the user's data, in plain statements that match what
/// the app does. Health Connect opens this page from its permission
/// screens; it is also under 我的.
///
/// Every line here is a promise the code keeps. Change the behaviour and
/// this page changes with it, or it becomes the thing it warns against.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final platform = store.healthSourceName;
    final kinds = [
      for (final kind in HealthDataKind.values)
        if (store.healthKinds.contains(kind)) kind.labelIn(context.l10n),
    ];
    final l10n = context.l10n;
    return DetailPage(
      appBar: PageAppBar(title: l10n.privacyLink),
      children: [
        _Facts(
          title: l10n.privacyStorage,
          facts: [
            (l10n.privacyRecords, l10n.privacyRecordsValue),
            (l10n.privacyWidgets, l10n.privacyWidgetsValue),
            (l10n.privacyAccount, l10n.none),
            (l10n.privacyServer, l10n.none),
            (l10n.privacyDeleted, l10n.privacyDeletedValue),
            (l10n.privacyUninstall, l10n.privacyUninstallValue),
          ],
        ),
        _Facts(
          title: l10n.privacyCameraSection,
          facts: [
            (l10n.privacyCamera, l10n.privacyCameraValue),
            (l10n.privacyPhotos, l10n.privacyPhotosValue),
            (l10n.privacyScalePhotos, l10n.privacyScalePhotosValue),
          ],
        ),
        _Facts(
          title: l10n.privacyHealthSection(platform: platform),
          facts: [
            (l10n.privacyPermission, l10n.privacyPermissionValue),
            (l10n.privacyReading, l10n.privacyReadingValue),
            (l10n.privacyLeavesDevice, l10n.privacyNo),
            (l10n.privacyToAi, l10n.privacyNo),
            (l10n.privacyAds, l10n.privacyNo),
            (l10n.privacyDisconnect, l10n.privacyDisconnectValue),
            if (kinds.isNotEmpty) (l10n.privacyKinds, joinList(l10n, kinds)),
          ],
        ),
        _Facts(
          title: 'AI',
          facts: [
            (l10n.privacyDefault, l10n.privacyNotUsed),
            ('Apple Intelligence', l10n.privacyAppleIntelligence),
            (l10n.privacyCloudReceives, l10n.privacyCloudReceivesValue),
            (l10n.privacyWebSearch, l10n.privacyWebSearchValue),
            (l10n.privacyFoodPhotos, l10n.privacyFoodPhotosValue),
            (l10n.privacyOtherData, l10n.privacyNotSent),
            (l10n.privacyFirstSend, l10n.privacyFirstSendValue(me: l10n.tabMe)),
            (l10n.privacyAiResults, l10n.privacyAiResultsValue),
            (l10n.privacyGoogleFree, l10n.privacyGoogleFreeValue),
          ],
        ),
        _Facts(
          title: l10n.privacyKeysSection,
          facts: [
            (l10n.privacyApiKeys, l10n.privacyApiKeysValue),
            (
              l10n.privacyExportFiles,
              l10n.privacyExportFilesValue(me: l10n.tabMe),
            ),
            (l10n.privacyExportContents, l10n.privacyExportContentsValue),
            (l10n.privacyUpload, l10n.none),
          ],
        ),
      ],
    );
  }
}

/// One area's promises, each a label and what the app does about it.
class _Facts extends StatelessWidget {
  const _Facts({required this.title, required this.facts});

  final String title;
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      label: title,
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              for (final (label, value) in facts)
                KeyValueRow(label: label, value: value),
            ],
          ),
        ),
      ],
    );
  }
}
