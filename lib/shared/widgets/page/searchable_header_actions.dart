import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';
import '../../motion.dart';
import '../chrome/chrome_surface.dart';
import 'collapsing_header.dart';

const _expandDuration = Duration(milliseconds: 320);
const _closeFadeDuration = Duration(milliseconds: 150);

/// A page's header actions ending in search. Tapping search stretches it
/// across the whole toolbar row into a text field, pushing the other
/// [actions] off to the left; closing shrinks it back.
///
/// It spans the toolbar row, so use it on pages whose toolbar shows no
/// title (`CompactBarBehavior.none`).
class SearchableHeaderActions extends StatefulWidget {
  const SearchableHeaderActions({
    super.key,
    required this.actions,
    required this.hint,
    required this.onChanged,
    this.searchLabel = '搜尋',
  });

  final List<Widget> actions;
  final String hint;

  /// The query as typed; empty once search closes.
  final ValueChanged<String> onChanged;

  /// What assistive tech reads for the collapsed search button.
  final String searchLabel;

  @override
  State<SearchableHeaderActions> createState() =>
      _SearchableHeaderActionsState();
}

class _SearchableHeaderActionsState extends State<SearchableHeaderActions>
    with SingleTickerProviderStateMixin {
  late final _expansion = AnimationController(vsync: this);
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  /// Leaving an empty field closes search; with a query it stays open so
  /// the results can be browsed with the keyboard down.
  void _onFocusChange() {
    if (_focus.hasFocus || _query.text.trim().isNotEmpty) return;
    if (_expansion.status
        case AnimationStatus.forward || AnimationStatus.completed) {
      _collapse();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _expansion.dispose();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    AppHaptics.tap();
    _expansion.duration = chromeDuration(context, _expandDuration);
    _expansion.forward();
  }

  void _close() {
    AppHaptics.tap();
    _query.clear();
    widget.onChanged('');
    _collapse();
  }

  void _collapse() {
    _expansion.duration = chromeDuration(context, _expandDuration);
    _expansion.reverse();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ToolbarMetrics.of(context);
    // Everything between the title slot's gutter and this slot's own: the
    // gap before an action and the gutter after the last one.
    // Never negative, even on a zero-width first frame.
    final fullWidth = math.max(
      0.0,
      MediaQuery.sizeOf(context).width -
          AppSpacing.screenGutter * 2 -
          AppSpacing.xs,
    );
    final collapsedWidth = metrics.actionHitSize;
    // Open, the field also covers the gap before this slot, so its left edge
    // lands on the page gutter.
    final openWidth = fullWidth + AppSpacing.xs;
    return SizedBox(
      width: fullWidth,
      height: metrics.actionHitSize,
      child: AnimatedBuilder(
        animation: _expansion,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_expansion.value);
          final searchWidth = lerpDouble(collapsedWidth, openWidth, t)!;
          final isOpen = _expansion.value > 0;
          return Stack(
            // No clip: the pushed actions travel on past the screen edge
            // instead of being cut off at this slot's edge.
            clipBehavior: Clip.none,
            children: [
              // Pushed ahead of the growing field, off the screen.
              Positioned(
                right: searchWidth + AppSpacing.xs,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: isOpen,
                  child: ExcludeSemantics(
                    excluding: isOpen,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < widget.actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.xs),
                            widget.actions[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: searchWidth,
                child: isOpen
                    ? _SearchBar(
                        controller: _query,
                        focusNode: _focus,
                        hint: widget.hint,
                        reveal: t,
                        fullWidth: openWidth,
                        onChanged: widget.onChanged,
                        onClose: _close,
                      )
                    : HeaderAction(
                        icon: Icons.search,
                        semanticLabel: widget.searchLabel,
                        onTap: _open,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.reveal,
    required this.fullWidth,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  /// 0 while still a button, 1 once fully stretched.
  final double reveal;
  final double fullWidth;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final metrics = ToolbarMetrics.of(context);
    final isSettled = reveal >= 1;
    return Center(
      child: SizedBox(
        height: metrics.actionVisualSize,
        // The same glass as the search button it grows from.
        child: ChromeSurface(
          refracts: true,
          tint: AppColors.surfaceRaised,
          // Laid out at full width from the start and revealed by the growing
          // pill, so the field never reflows while it stretches.
          child: OverflowBox(
            alignment: Alignment.centerRight,
            minWidth: fullWidth,
            maxWidth: fullWidth,
            child: Opacity(
              opacity: ((reveal - 0.4) / 0.6).clamp(0.0, 1.0),
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      // Built only once search opens, so this is the open.
                      autofocus: true,
                      // Tapping anywhere else puts the keyboard away.
                      onTapOutside: (_) => focusNode.unfocus(),
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  // Hidden until the field has fully stretched, then faded
                  // in; revealed any earlier it pops in at the growing edge.
                  AnimatedOpacity(
                    opacity: isSettled ? 1 : 0,
                    duration: chromeDuration(context, _closeFadeDuration),
                    child: IgnorePointer(
                      ignoring: !isSettled,
                      child: ExcludeSemantics(
                        excluding: !isSettled,
                        child: Semantics(
                          button: true,
                          label: '關閉搜尋',
                          onTap: onClose,
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onClose,
                            child: SizedBox.square(
                              dimension: metrics.actionVisualSize,
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
