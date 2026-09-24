import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import 'trends_view_model.dart';
import 'muscle_map_paths.dart';

/// Where the colour scale tops out. It is a drawing limit, not a
/// recommendation: nothing here says how many sets a muscle should get.
const muscleMapTopOfScale = 15;

/// The steps the legend prints under the figures.
const muscleMapLegendStops = [0, 5, 10, muscleMapTopOfScale];

/// The sets a drawn [muscle] is shaded by: its own, and those credited to
/// its whole region without saying which part.
int setsShownOn(MuscleGroup muscle, Map<MuscleGroup, int> setsByMuscle) =>
    (setsByMuscle[muscle] ?? 0) +
    setsByMuscle.entries
        .where(
          (entry) =>
              entry.key.isGeneral &&
              entry.key != muscle &&
              entry.key.region == muscle.region,
        )
        .fold(0, (sum, entry) => sum + entry.value);

/// Front and back figures, shaded by how many working sets each muscle
/// got. The shading answers "where did the work go"; the numbers beside
/// it answer "how much", and neither claims to know about fatigue.
///
/// Each drawn muscle is one muscle group. Sets credited to a whole region
/// — 「手臂」 on an exercise the user made — colour every muscle in it: the
/// figure never implies a detail the records do not have.
class MuscleMap extends StatelessWidget {
  const MuscleMap({
    super.key,
    required this.setsByMuscle,
    required this.figure,
  });

  /// Weekly working sets per muscle; anything missing is nothing logged.
  final Map<MuscleGroup, int> setsByMuscle;

  /// Which body to draw it on; the shading is the same either way.
  final MuscleFigure figure;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '肌群訓練量人體圖，詳細數值列在下方',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: muscleFigureSize.width * 2 / muscleFigureSize.height,
          child: Row(
            children: [
              for (final isBack in [false, true])
                Expanded(
                  child: CustomPaint(
                    // Without a child a painter has no size of its own.
                    size: Size.infinite,
                    painter: _FigurePainter(
                      setsByMuscle: setsByMuscle,
                      figure: figure,
                      isBack: isBack,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colour for [sets] working sets a week: neutral at nothing logged,
/// then steadily lighter up to the top of the scale. The scale is fixed,
/// so two weeks can be compared; shading against the week's own maximum
/// would make every week look the same.
Color muscleShade(int sets) {
  // Nothing logged looks like plain body: the figure says where the work
  // went, and silence is not a small amount of work.
  if (sets <= 0) return _restingMuscle;
  final t = (sets / muscleMapTopOfScale).clamp(0.0, 1.0);
  return Color.lerp(AppColors.trainingDim, AppColors.training, t)!;
}

/// A muscle with nothing counted for it, and the body behind them all.
const _restingMuscle = Color(0xFF2E3331);
const _bodyFill = Color(0xFF232624);

/// Parsing the same path data on every repaint would be wasted work, so
/// each figure is built once and kept. Only the ones actually drawn are
/// built, so choosing one body never costs the other.
final _figures = <(MuscleFigure, bool), _Figure>{};

_Figure _figureFor(MuscleFigure figure, {required bool isBack}) =>
    _figures.putIfAbsent(
      (figure, isBack),
      () => _Figure(
        outline: _parse(muscleOutlines[(figure, isBack)]!),
        muscles: [
          for (final shape in muscleShapes[(figure, isBack)]!)
            (shape.group, _parse(shape.path)),
        ],
      ),
    );

class _Figure {
  const _Figure({required this.outline, required this.muscles});

  final Path outline;
  final List<(MuscleGroup?, Path)> muscles;
}

Path _parse(String data) {
  final proxy = _PathBuilder();
  writeSvgPathDataToPath(data, proxy);
  return proxy.path;
}

/// Turns the parser's callbacks into a [Path]. `path_parsing` deals in
/// segments and leaves the drawing to us.
class _PathBuilder extends PathProxy {
  final path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

class _FigurePainter extends CustomPainter {
  const _FigurePainter({
    required this.setsByMuscle,
    required this.figure,
    required this.isBack,
  });

  final Map<MuscleGroup, int> setsByMuscle;
  final MuscleFigure figure;
  final bool isBack;

  @override
  void paint(Canvas canvas, Size size) {
    final drawing = _figureFor(figure, isBack: isBack);
    final scale = size.height / muscleFigureSize.height;
    canvas.save();
    canvas.translate((size.width - muscleFigureSize.width * scale) / 2, 0);
    canvas.scale(scale);

    canvas.drawPath(drawing.outline, Paint()..color = _bodyFill);
    for (final (group, path) in drawing.muscles) {
      canvas.drawPath(
        path,
        Paint()
          // A part with no group is one the app does not count; it stays
          // body-coloured rather than reading as "nothing done".
          ..color = group == null
              ? _bodyFill
              : muscleShade(setsShownOn(group, setsByMuscle)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.isBack != isBack ||
      old.figure != figure ||
      !_sameLoad(old.setsByMuscle, setsByMuscle);

  static bool _sameLoad(Map<MuscleGroup, int> a, Map<MuscleGroup, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
