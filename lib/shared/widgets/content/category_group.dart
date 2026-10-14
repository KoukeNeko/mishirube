import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../controls/chips.dart';

/// A category's name beside a dot in its colour, and a [tag] at the end.
/// A heading to a screen reader, as a section label is.
class CategoryHeading extends StatelessWidget {
  const CategoryHeading({
    super.key,
    required this.label,
    required this.color,
    this.tag,
    this.minHeight = 0,
  });

  final String label;
  final Color color;
  final Widget? tag;

  /// As tall as a touch target, for a page whose headings carry a link,
  /// so each sits as far above its group as every other: a heading that
  /// is only a name is then as tall as one with a link, its name on the
  /// bottom line.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Row(
          crossAxisAlignment: minHeight > 0
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.center,
          children: [
            // It takes the room the tag leaves, so a long name shortens.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  header: true,
                  child: CategoryLabel(label: label, color: color),
                ),
              ),
            ),
            ?tag,
          ],
        ),
      ),
    );
  }
}

/// A category of Today: its name under a dot in its colour, and what
/// belongs to it, one gap apart so it reads as one group.
class CategoryGroup extends StatelessWidget {
  const CategoryGroup({
    super.key,
    required this.label,
    required this.color,
    required this.children,
    this.tag,
    this.headingHeight = 0,
  });

  final String label;
  final Color color;

  /// Beside the name, at the end.
  final Widget? tag;

  /// See [CategoryHeading.minHeight].
  final double headingHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        CategoryHeading(
          label: label,
          color: color,
          tag: tag,
          minHeight: headingHeight,
        ),
        ...children,
      ],
    );
  }
}
