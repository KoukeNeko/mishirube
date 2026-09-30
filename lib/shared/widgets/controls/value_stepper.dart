import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'buttons.dart';

/// A figure with a step down and a step up beside it. What the figure is,
/// a [StepperReading] or a field to type over, is [child]; a step that is
/// null is disabled, at the end of what the figure can be.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.child,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
  });

  final Widget child;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SquareIconButton(
          icon: Icons.remove,
          tooltip: decreaseLabel,
          onPressed: onDecrease,
        ),
        Expanded(child: child),
        SquareIconButton(
          icon: Icons.add,
          tooltip: increaseLabel,
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

/// A figure and its unit, centred between a [ValueStepper]'s steps.
class StepperReading extends StatelessWidget {
  const StepperReading({super.key, required this.value, this.unit});

  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppTextStyles.bigNumber.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (unit case final unit?) ...[
          const SizedBox(width: AppSpacing.xxs),
          Text(unit, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}
