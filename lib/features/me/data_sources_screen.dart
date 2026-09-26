import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../app/navigation.dart';
import '../../backend/application/health_service.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'privacy_screen.dart';

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
      appBar: const PageAppBar(title: '資料來源'),
      children: [
        Gutter(child: const SectionLabel('手動輸入')),
        Gutter(
          child: _Counts(counts: typed, empty: '沒有紀錄。'),
        ),
        if (demo.isNotEmpty) ...[
          Gutter(child: const SectionLabel('示範資料')),
          Gutter(
            child: _Counts(counts: demo, empty: ''),
          ),
        ],
        Gutter(child: SectionLabel(store.healthSourceName)),
        const _HealthPlatform(),
        Gutter(child: const SectionLabel('匯入')),
        if (imports.isEmpty)
          Gutter(child: const Text('沒有匯入紀錄。', style: AppTextStyles.caption))
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
                    label: catalogue.label,
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
                for (final catalogue in catalogues)
                  if (catalogue.checkedAt case final at?)
                    '${catalogue.label}更新於 ${formatDate(at)}',
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
            KeyValueRow(label: category.label, value: '$count 筆'),
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
      toast.show(_summary(imported));
    } on Exception catch (error) {
      toast.show('讀取失敗：$error', kind: ToastKind.warning);
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
        message: '中斷連接後紀錄保留。',
        actions: [
          DialogAction(
            label: '立即讀取',
            onTap: () {
              Navigator.of(context).pop();
              _run(store.syncHealth);
            },
          ),
          DialogAction(
            label: '中斷連接',
            tone: DialogTone.destructive,
            onTap: () {
              Navigator.of(context).pop();
              store.disconnectHealth();
            },
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
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
                  ? '這台裝置沒有 ${store.healthSourceName}，或版本太舊。'
                  : '檢查中…',
              style: AppTextStyles.caption,
            ),
          );
        }
        final synced = store.lastHealthSync;
        final kinds = [
          for (final kind in HealthDataKind.values)
            if (store.healthKinds.contains(kind)) kind.label,
        ].join('、');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: store.isHealthConnected
                        ? '已連接'
                        : '連接 ${store.healthSourceName}',
                    subtitle: switch ((_isWorking, store.isHealthConnected)) {
                      (true, _) => '讀取中…',
                      (_, false) => '允許讀取',
                      (_, true) when store.healthSyncFailed => '上次自動讀取失敗',
                      (_, true) when synced != null =>
                        '上次讀取 ${formatDate(synced)} '
                            '${formatTimeOfDay(synced)}',
                      (_, true) => '已連接',
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
            Gutter(child: Text('讀取：$kinds', style: AppTextStyles.caption)),
            Gutter(
              child: LinkText(
                label: '隱私說明',
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
      return Gutter(child: const Text('檢查權限中…', style: AppTextStyles.caption));
    }
    final allowed = granted;
    if (allowed == null) {
      return Gutter(
        child: const Text(
          '權限在「設定 > 健康 > 資料存取與裝置 > MISHIRUBE」修改。',
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
                  label: kind.label,
                  value: allowed.contains(kind) ? '已允許' : '未允許',
                ),
              if (denied.isNotEmpty)
                NavRow(
                  title: '允許其他類別',
                  subtitle: denied.map((kind) => kind.label).join('、'),
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
String _summary(HealthImport? imported) {
  if (imported == null) return '沒有連上。';
  if (imported.foundNothing) {
    return switch (imported.denied) {
      final denied? when denied.isNotEmpty =>
        '沒有讀到資料。未允許：${denied.map((kind) => kind.label).join('、')}。',
      _ => '沒有讀到資料。到系統的健康設定確認允許的類別。',
    };
  }
  const units = {
    HealthDataKind.sleep: '晚',
    HealthDataKind.weight: '筆',
    HealthDataKind.waist: '筆',
    HealthDataKind.body: '筆',
    HealthDataKind.workouts: '次',
    HealthDataKind.water: '次',
    HealthDataKind.activity: '筆',
  };
  return [
    for (final MapEntry(key: kind, value: count) in imported.added.entries)
      if (count > 0) '${kind.label} $count ${units[kind]}',
    if (imported.updated > 0) '更新 ${imported.updated} 晚睡眠',
    if (imported.skipped > 0) '${imported.skipped} 晚保留手動紀錄',
    if (imported.denied case final denied? when denied.isNotEmpty)
      '未允許：${denied.map((kind) => kind.label).join('、')}',
  ].join('、');
}
