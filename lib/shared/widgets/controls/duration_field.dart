import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../format.dart';
import '../chrome/app_dialog.dart';
import 'inputs.dart';
import 'value_stepper.dart';

/// The most a time can be set to in [showDurationDialog].
const _maxMinutes = 999;

/// The step of the seconds; a time is not read closer than this.
const _secondStep = 5;

/// A time in whole seconds, shown as `m:ss` where an [InlineNumberField]
/// would be; a tap opens [showDurationDialog] and the new time is handed
/// to [onChanged].
class DurationField extends StatelessWidget {
  const DurationField({
    super.key,
    required this.seconds,
    required this.label,
    required this.onChanged,
  });

  final int seconds;

  /// What a screen reader and the dialog call it: `第 1 組時間`.
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InlineValueButton(
      label: label,
      onTap: () async {
        final chosen = await showDurationDialog(
          context,
          title: label,
          seconds: seconds,
        );
        if (chosen != null) onChanged(chosen);
      },
      child: Text(formatClock(Duration(seconds: seconds))),
    );
  }
}

/// Asks for a time: minutes one at a step, seconds five at a step. Resolves
/// to the seconds, or null when dismissed.
Future<int?> showDurationDialog(
  BuildContext context, {
  required String title,
  required int seconds,
}) => showAppDialog<int>(
  context,
  _DurationDialog(title: title, seconds: seconds),
);

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({required this.title, required this.seconds});

  final String title;
  final int seconds;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late int _minutes = (widget.seconds ~/ 60).clamp(0, _maxMinutes);
  late int _seconds = widget.seconds % 60;

  void _stepSeconds(int by) => setState(() {
    var next = _seconds + by;
    var minutes = _minutes;
    // Seconds carry into the minutes, both ways, within the limits.
    if (next >= 60 && minutes < _maxMinutes) {
      next -= 60;
      minutes++;
    } else if (next < 0 && minutes > 0) {
      next += 60;
      minutes--;
    }
    _seconds = next.clamp(0, 59);
    _minutes = minutes;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueStepper(
            decreaseLabel: l10n.decreaseBy(
              amount: l10n.durationMinutes(minutes: 1),
            ),
            increaseLabel: l10n.increaseBy(
              amount: l10n.durationMinutes(minutes: 1),
            ),
            onDecrease: _minutes > 0 ? () => setState(() => _minutes--) : null,
            onIncrease: _minutes < _maxMinutes
                ? () => setState(() => _minutes++)
                : null,
            child: StepperReading(value: '$_minutes', unit: l10n.unitMinutes),
          ),
          const SizedBox(height: AppSpacing.sm),
          ValueStepper(
            decreaseLabel: l10n.decreaseBy(
              amount: l10n.durationSeconds(seconds: _secondStep),
            ),
            increaseLabel: l10n.increaseBy(
              amount: l10n.durationSeconds(seconds: _secondStep),
            ),
            onDecrease: _minutes > 0 || _seconds > 0
                ? () => _stepSeconds(-_secondStep)
                : null,
            onIncrease: _minutes < _maxMinutes || _seconds < 59
                ? () => _stepSeconds(_secondStep)
                : null,
            child: StepperReading(
              value: _seconds.toString().padLeft(2, '0'),
              unit: l10n.unitSeconds,
            ),
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.commonSave,
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context).pop(_minutes * 60 + _seconds),
        ),
        DialogAction(
          label: l10n.commonCancel,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
