import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';

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
          ? const PageAppBar(title: '模組')
          : const PageAppBar(
              title: '你想用它做什麼？',
              subtitle: '選幾個都可以。只有你選的模組會被啟用，之後在「我的」隨時能改。',
              leading: AppBarLeading.none,
            ),
      footer: BottomActionBar(
        caption: '不需要註冊帳號，資料先留在這台裝置。',
        child: PrimaryButton(
          label: isEditing ? '完成' : '繼續',
          onPressed: enabled.isEmpty ? null : () => _continue(context),
        ),
      ),
      children: [
        for (final module in AppModule.values)
          _ModuleTile(
            module: module,
            isEnabled: enabled.contains(module),
            onTap: () => store.toggleModule(module),
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
      child: AppCard(
        tone: isEnabled ? CardTone.training : CardTone.neutral,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            CheckSquare(isChecked: isEnabled),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.title, style: AppTextStyles.itemTitle),
                  Text(module.description, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
