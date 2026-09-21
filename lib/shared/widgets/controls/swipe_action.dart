import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';
import '../../motion.dart';

/// Width of the action a swipe uncovers.
const _actionWidth = 88.0;
const _settleDuration = Duration(milliseconds: 200);

/// A row that slides towards its leading edge to uncover one
/// destructive action, which then takes a tap of its own.
///
/// Sliding only uncovers the action; however far it goes, nothing is
/// removed until the action is tapped. The gesture is a shortcut, so the
/// action is also offered to screen readers by name, and the page that
/// uses this keeps another visible way to do the same thing.
class SwipeAction extends StatefulWidget {
  const SwipeAction({
    super.key,
    required this.child,
    required this.label,
    required this.semanticLabel,
    required this.onAction,
    this.icon = Icons.delete_outline,
    this.radius = AppRadius.card,
  });

  final Widget child;

  /// What the uncovered action says: `移除`.
  final String label;

  /// The action as a screen reader offers it: `移除「豆漿」`.
  final String semanticLabel;
  final VoidCallback onAction;
  final IconData icon;

  /// The corners of [child], which the action behind it follows.
  final double radius;

  @override
  State<SwipeAction> createState() => _SwipeActionState();
}

class _SwipeActionState extends State<SwipeAction>
    with SingleTickerProviderStateMixin {
  /// 0 closed, 1 fully uncovered.
  late final _open = AnimationController(vsync: this);

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  /// Towards the leading edge: left in a left-to-right language.
  double get _direction =>
      Directionality.of(context) == TextDirection.ltr ? -1 : 1;

  void _settle(bool open) => _open.animateTo(
    open ? 1 : 0,
    duration: chromeDuration(context, _settleDuration),
    curve: Curves.easeOut,
  );

  void _onDragUpdate(DragUpdateDetails details) {
    _open.value += details.primaryDelta! * _direction / _actionWidth;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity! * _direction;
    _settle(velocity > 300 || (velocity > -300 && _open.value > 0.5));
  }

  void _act() {
    AppHaptics.tap();
    _open.value = 0;
    widget.onAction();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.semanticLabel): widget.onAction,
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          children: [
            // Painted only while the row is moved, so it never shows at
            // the row's rounded corners.
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: _open,
                builder: (context, open, child) =>
                    open > 0 ? child! : const SizedBox.shrink(),
                child: ExcludeSemantics(
                  child: ColoredBox(
                    color: AppColors.destructive,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: SizedBox(
                        width: _actionWidth,
                        child: InkWell(
                          onTap: _act,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widget.icon, color: AppColors.textPrimary),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: AnimatedBuilder(
                animation: _open,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_direction * _open.value * _actionWidth, 0),
                  child: child,
                ),
                child: widget.child,
              ),
            ),
            // While open, a tap on the row closes it rather than doing
            // what the row does.
            ValueListenableBuilder(
              valueListenable: _open,
              builder: (context, open, _) => open > 0
                  ? PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      end: _actionWidth * open,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _settle(false),
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
