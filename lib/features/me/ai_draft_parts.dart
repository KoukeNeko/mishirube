import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'ai_settings_screen.dart';

// The pieces every 一句話 page shares — what the user writes, which AI it
// goes to, the button that sends it, why it came back with nothing, and
// which AI the draft came from — so the meal's and the workout's read as
// one feature.

/// `Ollama Cloud / gemma4:31b`: which AI, and which of its models. Apple's
/// on-device model and Copilot offer no model to choose, so they are named
/// alone.
String aiLabel(AiProviderKind provider, String model) =>
    model.isEmpty ||
        model == provider.label ||
        provider == AiProviderKind.appleOnDevice
    ? provider.label
    : '${provider.label} / $model';

/// The AI a 一句話 page would send to now, for under its title.
String currentAiLabel(AppStore store) => switch (store.aiProvider) {
  final provider? => aiLabel(provider, store.aiModel),
  null => 'AI 未啟用',
};

/// Where the user writes what to draft.
class DescribeField extends StatelessWidget {
  const DescribeField({
    super.key,
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) =>
      AppTextField(controller: controller, hint: hint, maxLines: 6);
}

/// Sends what was written; reads 產生中… while the draft is being made.
class DraftButton extends StatelessWidget {
  const DraftButton({
    super.key,
    required this.isDrafting,
    required this.onPressed,
    this.label = '產生草稿',
  });

  final bool isDrafting;

  /// Null while there is nothing to send.
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => PrimaryButton(
    label: isDrafting ? '產生中…' : label,
    onPressed: isDrafting ? null : onPressed,
  );
}

/// Why the AI made no draft.
class AiFailureBanner extends StatelessWidget {
  const AiFailureBanner({super.key, required this.failure});

  final AiFailure failure;

  @override
  Widget build(BuildContext context) =>
      InfoBanner(tone: CardTone.warning, message: aiFailureMessage(failure));
}

/// Which AI a draft came from, under it: `Ollama Cloud / gemma4:31b`.
class DraftAttribution extends StatelessWidget {
  const DraftAttribution({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.auto_awesome_outlined,
        size: 16,
        color: AppColors.textSecondary,
      ),
      const SizedBox(width: AppSpacing.xxs),
      Flexible(child: Text(label, style: AppTextStyles.caption)),
    ],
  );
}

/// Back to what was written, to write it again.
class RewriteLink extends StatelessWidget {
  const RewriteLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: LinkText(label: '重新輸入', onTap: onTap),
  );
}
