import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../app/navigation.dart';
import '../../backend/application/health_service.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'privacy_screen.dart';
import '../../l10n/l10n.dart';

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
      appBar: PageAppBar(title: context.l10n.dataSourcesLink),
      children: [
        Gutter(child: SectionLabel(context.l10n.sourceManual)),
        Gutter(
          child: _Counts(counts: typed, empty: context.l10n.noEntriesSentence),
        ),
        if (demo.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.sourceDemo)),
          Gutter(
            child: _Counts(counts: demo, empty: ''),
          ),
        ],
        Gutter(child: SectionLabel(store.healthSourceName)),
        const _HealthPlatform(),
        Gutter(child: SectionLabel(context.l10n.sourceImport)),
        if (imports.isEmpty)
          Gutter(
            child: Text(context.l10n.noImports, style: AppTextStyles.caption),
          )
        else
          Gutter(
            child: GroupedCard(
              children: [
                for (final record in imports)
                  KeyValueRow(
                    label: record.fileName ?? record.source,
                    value: record.isUndone
                        ? context.l10n.importUndone
                        : '${context.l10n.readingsCount(count: record.records)} · '
                              '${context.dates.date(record.importedAt)}',
                  ),
              ],
            ),
          ),
        if (catalogues.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.sourceCatalogue)),
          Gutter(
            child: GroupedCard(
              children: [
                for (final catalogue in catalogues)
                  KeyValueRow(
                    label: catalogue.labelIn(context.l10n),
                    value:
                        '${context.l10n.productsCount(count: catalogue.products)} · '
                        '${context.l10n.foodCupSizes(count: catalogue.sizes)}',
                  ),
              ],
            ),
          ),
          Gutter(
            child: Text(
              [
                for (final catalogue in catalogues)
                  if (catalogue.checkedAt case final at?)
                    context.l10n.catalogueUpdated(
                      catalogue: catalogue.labelIn(context.l10n),
                      date: context.dates.date(at),
                    ),
              ].join('\n'),
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
            KeyValueRow(
              label: category.labelIn(context.l10n),
              value: context.l10n.readingsCount(count: count),
            ),
      ],
    );
  }
}

/// Apple Health or Health Connect: connect once, then read again on
/// every launch. Read only — nothing goes back to the platform.
class _HealthPlatform extends StatefulWidget {
  const _HealthPlatform();

  @override
  State<_HealthPlatform> createState() => _HealthPlatformState();
}

class _HealthPlatformState extends State<_HealthPlatform> {
  late final Future<bool> _isAvailable = AppStoreScope.read(context)
      .isHealthAvailable();

  /// Read again after every connect, sync or request: the user may have
  /// changed what is allowed in the platform's own settings meanwhile.
  late Future<Set<HealthDataKind>?> _granted = _readGranted();
  bool _isWorking = false;

  Future<Set<HealthDataKind>?> _readGranted() {
    final store = AppStoreScope.read(context);
    return store.isHealthConnected
        ? store.healthGrantedKinds()
        : Future.value(const <HealthDataKind>{});
  }

  Future<void> _run(Future<HealthImport?> Function() action) async {
    final toast = ToastScope.read(context);
    setState(() => _isWorking = true);
    try {
      final imported = await action();
      if (!mounted) return;
      toast.show(_summary(context.l10n, imported));
    } on Exception catch (error) {
      if (!mounted) return;
      toast.show(
        context.l10n.healthReadFailed(error: '$error'),
        kind: ToastKind.warning,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _granted = _readGranted();
        });
      }
    }
  }

  Future<void> _manage() async {
    final store = AppStoreScope.read(context);
    await showAppDialog<void>(
      context,
      AppDialog(
        title: store.healthSourceName,
        message: context.l10n.healthDisconnectKeeps,
        actions: [
          DialogAction(
            label: context.l10n.healthReadNow,
            onTap: () {
              Navigator.of(context).pop();
              _run(store.syncHealth);
            },
          ),
          DialogAction(
            label: context.l10n.healthDisconnect,
            tone: DialogTone.destructive,
            onTap: () {
              Navigator.of(context).pop();
              store.disconnectHealth();
            },
          ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    return FutureBuilder(
      future: _isAvailable,
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return Gutter(
            child: Text(
              snapshot.hasData
                  ? context.l10n.healthUnavailable(
                      source: store.healthSourceName,
                    )
                  : context.l10n.checking,
              style: AppTextStyles.caption,
            ),
          );
        }
        final synced = store.lastHealthSync;
        final kinds = [
          for (final kind in HealthDataKind.values)
            if (store.healthKinds.contains(kind)) kind.labelIn(context.l10n),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: store.isHealthConnected
                        ? context.l10n.healthConnected
                        : context.l10n.healthConnect(
                            source: store.healthSourceName,
                          ),
                    subtitle: switch ((_isWorking, store.isHealthConnected)) {
                      (true, _) => context.l10n.healthReading,
                      (_, false) => context.l10n.healthAllowReading,
                      (_, true) when store.healthSyncFailed =>
                        context.l10n.healthAutoReadFailed,
                      (_, true) when synced != null =>
                        context.l10n.healthLastRead(
                          when:
                              '${context.dates.date(synced)} '
                              '${formatTimeOfDay(synced)}',
                        ),
                      (_, true) => context.l10n.healthConnected,
                    },
                    onTap: _isWorking
                        ? null
                        : store.isHealthConnected
                        ? _manage
                        : () => _run(store.connectHealth),
                  ),
                ],
              ),
            ),
            if (store.isHealthConnected)
              FutureBuilder(
                future: _granted,
                builder: (context, snapshot) => _Permissions(
                  kinds: [
                    for (final kind in HealthDataKind.values)
                      if (store.healthKinds.contains(kind)) kind,
                  ],
                  granted: snapshot.data,
                  isKnown: snapshot.connectionState == ConnectionState.done,
                  onAskAgain: _isWorking
                      ? null
                      : () => _run(store.askHealthAgain),
                ),
              ),
            Gutter(
              child: Text(
                context.l10n.healthReads(kinds: joinList(context.l10n, kinds)),
                style: AppTextStyles.caption,
              ),
            ),
            Gutter(
              child: LinkText(
                label: context.l10n.privacyLink,
                onTap: () => pushPage(context, const PrivacyScreen()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Which kinds the user allowed. Health Connect says; Apple Health
/// does not, on purpose, so there the page says what that means instead
/// of guessing.
class _Permissions extends StatelessWidget {
  const _Permissions({
    required this.kinds,
    required this.granted,
    required this.isKnown,
    required this.onAskAgain,
  });

  final List<HealthDataKind> kinds;

  /// Null when the platform will not say.
  final Set<HealthDataKind>? granted;
  final bool isKnown;
  final VoidCallback? onAskAgain;

  @override
  Widget build(BuildContext context) {
    if (!isKnown) {
      return Gutter(
        child: Text(
          context.l10n.checkingPermissions,
          style: AppTextStyles.caption,
        ),
      );
    }
    final allowed = granted;
    if (allowed == null) {
      return Gutter(
        child: Text(
          context.l10n.healthPermissionsPath,
          style: AppTextStyles.caption,
        ),
      );
    }
    final denied = [
      for (final kind in kinds)
        if (!allowed.contains(kind)) kind,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              for (final kind in kinds)
                KeyValueRow(
                  label: kind.labelIn(context.l10n),
                  value: allowed.contains(kind)
                      ? context.l10n.permissionAllowed
                      : context.l10n.permissionDenied,
                ),
              if (denied.isNotEmpty)
                NavRow(
                  title: context.l10n.healthAllowOthers,
                  subtitle: joinList(
                    context.l10n,
                    denied.map((kind) => kind.labelIn(context.l10n)),
                  ),
                  onTap: onAskAgain,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What an import did, in a sentence; or why nothing came in.
String _summary(AppLocalizations l10n, HealthImport? imported) {
  if (imported == null) return l10n.healthNotConnected;
  String kinds(Iterable<HealthDataKind> denied) =>
      joinList(l10n, denied.map((kind) => kind.labelIn(l10n)));
  if (imported.foundNothing) {
    return switch (imported.denied) {
      final denied? when denied.isNotEmpty => l10n.healthNothingReadDenied(
        kinds: kinds(denied),
      ),
      _ => l10n.healthNothingRead,
    };
  }
  String counted(HealthDataKind kind, int count) => switch (kind) {
    HealthDataKind.sleep => l10n.nightsCount(count: count),
    HealthDataKind.workouts ||
    HealthDataKind.water => l10n.timesCount(count: count),
    _ => l10n.readingsCount(count: count),
  };
  return joinList(l10n, [
    for (final MapEntry(key: kind, value: count) in imported.added.entries)
      if (count > 0) '${kind.labelIn(l10n)} ${counted(kind, count)}',
    if (imported.updated > 0) l10n.healthUpdatedNights(count: imported.updated),
    if (imported.skipped > 0) l10n.healthKeptManual(count: imported.skipped),
    if (imported.denied case final denied? when denied.isNotEmpty)
      l10n.healthNotAllowedList(kinds: kinds(denied)),
  ]);
}
