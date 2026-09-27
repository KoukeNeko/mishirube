import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// First-run module picker; also reused from「我的 → 模組」for editing.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  void _continue(BuildContext context) {
    final store = AppStoreScope.read(context);
    if (isEditing) {
      Navigator.of(context).pop();
      return;
    }
    store.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final enabled = store.enabledModules;
    return PageScaffold(
      appBar: isEditing
          ? PageAppBar(title: context.l10n.modulesTitle)
          : PageAppBar(
              title: context.l10n.modulesTitle,
              subtitle: context.l10n.modulesPickSeveral,
              leading: AppBarLeading.none,
            ),
      footer: BottomActionBar(
        child: PrimaryButton(
          label: isEditing
              ? context.l10n.commonDone
              : context.l10n.commonContinue,
          onPressed: enabled.isEmpty ? null : () => _continue(context),
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
