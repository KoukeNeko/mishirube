import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'ai_settings_screen.dart';
import '../../l10n/l10n.dart';

// The pieces every 一句話 page shares — what the user writes, which AI it
// goes to, the button that sends it, why it came back with nothing, and
// which AI the draft came from — so the meal's and the workout's read as
// one feature.

/// `Ollama Cloud / gemma4:31b`: which AI, and which of its models. Apple's
/// on-device model and Copilot offer no model to choose, so they are named
/// alone.
String aiLabel(AppLocalizations l10n, AiProviderKind provider, String model) =>
    model.isEmpty ||
        model == provider.labelIn(l10n) ||
        provider == AiProviderKind.appleOnDevice
    ? provider.labelIn(l10n)
    : '${provider.labelIn(l10n)} / $model';

/// The AI a 一句話 page would send to now, for under its title.
String currentAiLabel(AppLocalizations l10n, AppStore store) =>
    switch (store.aiProvider) {
      final provider? => aiLabel(l10n, provider, store.aiModel),
      null => l10n.aiOff,
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
    this.label,
  });

  final bool isDrafting;

  /// Null while there is nothing to send.
  final VoidCallback? onPressed;

  /// 產生草稿 when null.
  final String? label;

  @override
  Widget build(BuildContext context) => PrimaryButton(
    label: isDrafting
        ? context.l10n.aiDrafting
        : label ?? context.l10n.aiDraftGenerate,
    onPressed: isDrafting ? null : onPressed,
  );
}

/// Why the AI made no draft.
class AiFailureBanner extends StatelessWidget {
  const AiFailureBanner({super.key, required this.failure});

  final AiFailure failure;

  @override
  Widget build(BuildContext context) => InfoBanner(
    tone: CardTone.warning,
    message: aiFailureMessage(context.l10n, failure),
  );
}

/// The model's reasoning as it streams in, while a draft is being made:
/// a capped, self-scrolling panel that stays pinned to the newest line,
/// collapsible for when the draft is what the user is waiting for. Shown
/// only where the provider reasons out loud, so it is absent for the
/// on-device model and any provider that returns its answer in one piece.
class AiThinkingView extends StatefulWidget {
  const AiThinkingView({super.key, required this.text});

  final String text;

  @override
  State<AiThinkingView> createState() => _AiThinkingViewState();
}

/// Tall enough to follow the reasoning, short enough to keep the button
/// and what is being read in view.
const _thinkingMaxHeight = 160.0;

class _AiThinkingViewState extends State<AiThinkingView> {
  bool _isOpen = true;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isOpen = !_isOpen),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    context.l10n.aiThinking,
                    style: AppTextStyles.caption,
                  ),
                ),
                Icon(
                  _isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _thinkingMaxHeight),
              // Reversed so the newest text stays in view without a
              // controller chasing the extent on every token.
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  widget.text,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
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
    child: LinkText(label: context.l10n.aiRewrite, onTap: onTap),
  );
}
