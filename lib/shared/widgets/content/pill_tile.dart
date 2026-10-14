import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'level_fill.dart';

/// One of the day's figures as a pill: a darker capsule at the left that
/// holds its mark, the name over the figure. Tinted in its area's colour
/// when there is a figure, grey when there is none. It may be filled from
/// the left as far as [progress] (a bar against a target), or up from the
/// bottom as [level] (water in a glass), never both.
class PillTile extends StatelessWidget {
  const PillTile({
    super.key,
    required this.label,
    required this.color,
    required this.surface,
    required this.outline,
    required this.leading,
    required this.placeholder,
    this.value,
    this.unit,
    this.caption,
    this.progress,
    this.level,
    this.motion,
    this.isCompact = false,
    this.onTap,
  });

  final String label;

  /// The area's colour, which the text and the fill are drawn in.
  final Color color;
  final Color surface;
  final Color outline;

  /// What sits in the capsule: an icon, or a dot.
  final Widget leading;

  /// Said in place of the figure when [value] is null.
  final String placeholder;
  final String? value;
  final String? unit;

  /// Said after the name, small: what the figure is measured against or
  /// how it changed.
  final String? caption;

  /// 0–1 from the left.
  final double? progress;

  /// 0–1 from the bottom, drawn as water that answers [motion].
  final double? level;
  final Stream<Offset>? motion;

  /// A pill with a line less in it, for the parts of one figure.
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final hasValue = value != null;
    final tint = hasValue ? color : AppColors.textSecondary;
    final base = hasValue ? surface : AppColors.surface;
    final edge = hasValue ? outline : AppColors.outline;
    final capsule = Color.alphaBlend(const Color(0x66000000), base);
    final capsuleWidth = isCompact ? 32.0 : 44.0;
    final height = isCompact ? 52.0 : 68.0;
    final named = caption == null ? label : '$label · $caption';

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          named,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: Color.lerp(tint, Colors.white, hasValue ? 0.45 : 0),
            height: 1.25,
          ),
        ),
        if (value == null)
          Text(
            placeholder,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: AppTextStyles.bigNumber.copyWith(
                      fontSize: isCompact ? 17 : 20,
                      color: Color.lerp(tint, Colors.white, 0.85),
                    ),
                  ),
                  if (unit case final unit?)
                    TextSpan(
                      text: ' $unit',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: Color.lerp(tint, Colors.white, 0.45),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: [
        named,
        if (value == null) placeholder else ...[value, ?unit],
      ].join(' '),
      child: ExcludeSemantics(
        child: Material(
          color: base,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2 - 4),
            side: BorderSide(color: edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (hasValue && level != null)
                    Positioned.fill(
                      child: LevelFill(
                        level: level!,
                        color: color,
                        motion: motion,
                      ),
                    ),
                  if (hasValue && progress != null)
                    Positioned.fill(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          key: const ValueKey('pill-fill'),
                          widthFactor: progress!.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: ColoredBox(
                            color: color.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: capsuleWidth,
                            decoration: BoxDecoration(
                              color: capsule,
                              borderRadius: BorderRadius.circular(
                                capsuleWidth / 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: IconTheme(
                              data: IconThemeData(color: tint, size: 22),
                              child: leading,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: text),
                        ],
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
