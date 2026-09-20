import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../motion.dart';
import 'chrome_surface.dart';

/// How long the dialog takes to arrive; leaving plays the same backwards.
const _dialogDuration = Duration(milliseconds: 220);

/// Wide enough for a sentence, narrow enough to stay a dialog.
const _maxDialogWidth = 400.0;

const _enterScale = 0.92;

/// The app's own dialog, in the same frosted glass as the rest of the
/// floating chrome. Actions are stacked full width and built from the
/// app's buttons, so a dialog's choices look like every other choice.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.content,
  });

  final String title;

  /// One line or two about what the choices mean.
  final String? message;

  /// Anything the dialog asks for, such as a text field.
  final Widget? content;

  /// Most important first: they are read top to bottom. Built with the
  /// dialog's own context, so an action closes it by popping that.
  final List<Widget> Function(BuildContext context) actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxDialogWidth),
          child: ChromeSurface(
            radius: AppRadius.card,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppTextStyles.cardTitle),
                  if (message case final message?) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(message, style: AppTextStyles.body),
                  ],
                  if (content case final content?) ...[
                    const SizedBox(height: AppSpacing.md),
                    content,
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  for (final (index, action) in actions(context).indexed) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.xs),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [dialog] over a dimmed app. It grows out of the middle and folds
/// back the same way, like the rest of the chrome.
Future<T?> showAppDialog<T>(BuildContext context, Widget dialog) {
  final duration = chromeDuration(context, _dialogDuration);
  return Navigator.of(context).push(
    RawDialogRoute<T>(
      barrierDismissible: true,
      barrierLabel: '關閉',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: duration,
      pageBuilder: (_, _, _) => dialog,
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: _enterScale, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
