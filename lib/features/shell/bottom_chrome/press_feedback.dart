import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'chrome_metrics.dart';

/// Shrinks [child] the moment a finger lands and springs it back on
/// release. It reacts to the raw pointer, not the recognised tap, so there
/// is feedback before the tap is decided; the child still handles the tap.
/// With reduced motion it stays still and only reports the press.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.pressedScale,
    required this.child,
    this.onPressedChanged,
  });

  final double pressedScale;
  final Widget child;
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);

  void _setPressed(bool isPressed) {
    widget.onPressedChanged?.call(isPressed);
    if (prefersReducedMotion(context)) {
      _scale.value = 1;
    } else if (isPressed) {
      _scale.animateTo(
        widget.pressedScale,
        duration: ChromeMetrics.pressDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _scale.animateWith(
        SpringSimulation(
          ChromeMetrics.pressSpring,
          _scale.value,
          1,
          _scale.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
