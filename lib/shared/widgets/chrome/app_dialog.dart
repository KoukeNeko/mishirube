import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';
import '../../motion.dart';
import 'chrome_surface.dart';

/// How long the dialog takes to arrive; leaving is quicker, the way the
/// system's own alerts behave.
const _enterDuration = Duration(milliseconds: 200);
const _exitDuration = Duration(milliseconds: 140);

/// Wide enough for a sentence, narrow enough to stay a dialog.
const _maxDialogWidth = 356.0;

const _enterScale = 0.96;

/// Tall enough to hit, short enough that three of them are still a list.
const _actionHeight = 52.0;

/// What a choice does, which is all the styling it needs.
enum DialogTone {
  /// What the dialog is really asking for.
  primary,

  /// An ordinary way out.
  normal,

  /// Loses something for good.
  destructive,
}

/// One choice in an [AppDialog].
class DialogAction {
  const DialogAction({
    required this.label,
    required this.onTap,
    this.tone = DialogTone.normal,
  });

  final String label;
  final VoidCallback onTap;
  final DialogTone tone;

  Color get _color => switch (tone) {
    DialogTone.primary => AppColors.training,
    DialogTone.normal => AppColors.textPrimary,
    DialogTone.destructive => AppColors.destructive,
  };
}

/// The app's own dialog. The choices are rows, not buttons: a dialog is
/// read and answered, so the accent belongs on one label rather than on a
/// slab of colour that outweighs the question.
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

  /// Most important first: they are read top to bottom.
  final List<DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxDialogWidth),
          child: ChromeSurface(
            radius: _dialogRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _titleStyle),
                      if (message case final message?) ...[
                        const SizedBox(height: AppSpacing.xxs + 2),
                        Text(message, style: _messageStyle),
                      ],
                      if (content case final content?) ...[
                        const SizedBox(height: AppSpacing.md),
                        content,
                      ],
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) =>
                      _actionArea(context, constraints.maxWidth),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Two short choices read faster side by side; anything else stacks.
  /// The test is whether the labels actually fit at the reader's text
  /// size, not how many characters they have — a longer translation or
  /// larger type has to fall back on its own.
  Widget _actionArea(BuildContext context, double width) {
    if (actions.length == 2) {
      final slot = (width - _hairline) / 2;
      final fits = actions.every(
        (action) =>
            _labelWidth(context, action.label) + AppSpacing.lg * 2 <= slot,
      );
      if (fits) {
        // Leading is the way out, trailing is what the dialog asked for,
        // which is where both iOS and Material put them.
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _separator)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ActionRow(action: actions[1], isCentered: true),
                ),
                const VerticalDivider(
                  width: _hairline,
                  thickness: _hairline,
                  color: _separator,
                ),
                Expanded(
                  child: _ActionRow(action: actions.first, isCentered: true),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final action in actions) _ActionRow(action: action)],
    );
  }

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _actionStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}

const _dialogRadius = 24.0;

/// One device pixel, whichever device it is.
const _hairline = 1.0;

const _titleStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 20,
  height: 1.3,
  fontWeight: FontWeight.w700,
);

const _messageStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 15,
  height: 1.45,
);

const _actionStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

/// A hairline between choices, so they read as one list instead of three
/// separate blocks.
const _separator = Color(0x14FFFFFF);

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, this.isCentered = false});

  final DialogAction action;

  /// Side by side the labels are centred in their half; stacked they line
  /// up with the title.
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    final color = action._color;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isCentered
            ? null
            : const Border(top: BorderSide(color: _separator)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptics.tap();
            action.onTap();
          },
          // Pressing stains the row in its own colour instead of moving it.
          highlightColor: color.withValues(alpha: 0.12),
          splashColor: color.withValues(alpha: 0.08),
          child: Container(
            height: _actionHeight,
            alignment: isCentered
                ? Alignment.center
                : AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              action.label,
              style: _actionStyle.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [dialog] over a dimmed app. It grows a little as it fades in and
/// settles back the same way; nothing slides.
Future<T?> showAppDialog<T>(BuildContext context, Widget dialog) {
  return Navigator.of(context).push(
    _AppDialogRoute<T>(
      reverseDuration: chromeDuration(context, _exitDuration),
      barrierDismissible: true,
      barrierLabel: '關閉',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: chromeDuration(context, _enterDuration),
      pageBuilder: (_, _, _) => dialog,
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
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

/// Leaving is quicker than arriving, which `RawDialogRoute` cannot say on
/// its own.
class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required this.reverseDuration,
    required super.pageBuilder,
    super.barrierDismissible,
    super.barrierLabel,
    super.barrierColor,
    super.transitionDuration,
    super.transitionBuilder,
  });

  final Duration reverseDuration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;
}
