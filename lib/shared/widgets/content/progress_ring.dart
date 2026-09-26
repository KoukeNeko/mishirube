import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

const _startAngle = -math.pi / 2;

/// How far something has got, as a ring filling clockwise from the top,
/// with whatever the page puts in its middle: a [title] running along
/// the inside of the ring's top, [child] in the centre and a [footer]
/// running along the inside of its bottom, in the ring's colour.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.semanticLabel,
    this.size = 148,
    this.strokeWidth = 10,
    this.title,
    this.child,
    this.footer,
  });

  /// From 0 to 1; anything past either end is drawn at it.
  final double progress;
  final Color color;
  final String semanticLabel;
  final double size;
  final double strokeWidth;
  final String? title;
  final Widget? child;
  final String? footer;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          color: color,
          title: title,
          titleStyle: AppTextStyles.caption,
          footer: footer,
          footerStyle: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          textScaler: MediaQuery.textScalerOf(context),
        ),
        // The middle shrinks to stay inside the ring, at any text size.
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(strokeWidth + AppSpacing.xs),
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.title,
    required this.titleStyle,
    required this.footer,
    required this.footerStyle,
    required this.textScaler,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final String? title;
  final TextStyle titleStyle;
  final String? footer;
  final TextStyle footerStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceRaised;
    canvas.drawCircle(centre, radius, track);
    final inner = radius - strokeWidth / 2;
    if (title case final title? when title.isNotEmpty) {
      _paintArc(canvas, centre, inner, title, titleStyle, atTop: true);
    }
    if (footer case final footer? when footer.isNotEmpty) {
      _paintArc(canvas, centre, inner, footer, footerStyle, atTop: false);
    }
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      _startAngle,
      progress * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  /// [text] centred on the top or the bottom just inside [inner], the
  /// ring's inner edge, reading left to right with each character upright
  /// to the circle: its top points out at the top and in at the bottom.
  void _paintArc(
    Canvas canvas,
    Offset centre,
    double inner,
    String text,
    TextStyle style, {
    required bool atTop,
  }) {
    final letters = [
      for (final letter in text.characters)
        TextPainter(
          text: TextSpan(text: letter, style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(),
    ];
    final height = letters.map((l) => l.height).reduce(math.max);
    final pathRadius = inner - AppSpacing.xxs - height / 2;
    if (pathRadius <= 0) return;
    final width = letters.fold(0.0, (sum, letter) => sum + letter.width);
    // Left to right runs clockwise over the top and anticlockwise under
    // the bottom.
    final direction = atTop ? 1 : -1;
    final middleAngle = atTop ? -math.pi / 2 : math.pi / 2;
    var angle = middleAngle - direction * width / pathRadius / 2;
    for (final letter in letters) {
      final middle = angle + direction * letter.width / pathRadius / 2;
      canvas
        ..save()
        ..translate(
          centre.dx + pathRadius * math.cos(middle),
          centre.dy + pathRadius * math.sin(middle),
        )
        ..rotate(middle - middleAngle);
      letter.paint(canvas, Offset(-letter.width / 2, -letter.height / 2));
      canvas.restore();
      angle += direction * letter.width / pathRadius;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.title != title ||
      old.titleStyle != titleStyle ||
      old.footer != footer ||
      old.footerStyle != footerStyle ||
      old.textScaler != textScaler;
}
