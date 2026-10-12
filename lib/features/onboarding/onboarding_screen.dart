import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';
import '../me/data_sources_screen.dart';

/// First-run module picker; also reused from「我的 → 模組」for editing.
///
/// Finishing it on Android first offers to connect Health Connect: only
/// the data sources page connects it otherwise, and until it is
/// connected nothing is read.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isFinishing = false;

  Future<void> _continue() async {
    final store = AppStoreScope.read(context);
    if (widget.isEditing) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = context.l10n;
    final toast = ToastScope.read(context);
    setState(() => _isFinishing = true);
    final connect = await _offerHealth(store);
    store.completeOnboarding();
    if (!connect) return;
    try {
      toast.show(healthImportSummary(l10n, await store.connectHealth()));
    } on Exception catch (error) {
      toast.show(
        l10n.healthReadFailed(error: '$error'),
        kind: ToastKind.warning,
      );
    }
  }

  /// Whether the user chose to connect the health platform; false where
  /// it is not offered.
  Future<bool> _offerHealth(AppStore store) async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        store.isHealthConnected) {
      return false;
    }
    if (!await store.isHealthAvailable() || !mounted) return false;
    final connect = await showAppDialog<bool>(
      context,
      AppDialog(
        title: store.healthSourceName,
        message: healthReadsLine(context, store),
        actions: [
          DialogAction(
            label: context.l10n.healthConnect(source: store.healthSourceName),
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    return connect ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final enabled = store.enabledModules;
    return PageScaffold(
      appBar: widget.isEditing
          ? PageAppBar(title: context.l10n.modulesTitle)
          : PageAppBar(
              title: context.l10n.modulesTitle,
              subtitle: context.l10n.modulesPickSeveral,
              leading: AppBarLeading.none,
            ),
      footer: BottomActionBar(
        child: PrimaryButton(
          label: widget.isEditing
              ? context.l10n.commonDone
              : context.l10n.commonContinue,
          onPressed: enabled.isEmpty || _isFinishing ? null : _continue,
        ),
      ),
      children: [
        for (final module in AppModule.values)
          Gutter(
            child: _ModuleTile(
              module: module,
              isEnabled: enabled.contains(module),
              onTap: () => store.toggleModule(module),
            ),
          ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.isEnabled,
    required this.onTap,
  });

  final AppModule module;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: isEnabled,
      child: NavCard(
        tone: isEnabled ? CardTone.training : CardTone.neutral,
        leading: CheckSquare(isChecked: isEnabled),
        title: module.title(context.l10n),
        subtitle: module.description(context.l10n),
        onTap: onTap,
        showChevron: false,
      ),
    );
  }
}
