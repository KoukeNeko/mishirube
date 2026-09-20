import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';

/// The figure is drawn in this space and scaled to fit, so every shape
/// below is written once in round numbers.
const _figureWidth = 100.0;
const _figureHeight = 220.0;

/// Where the colour scale tops out. It is a drawing limit, not a
/// recommendation: nothing here says how many sets a muscle should get.
const muscleMapTopOfScale = 15;

/// The steps the legend prints under the figures.
const muscleMapLegendStops = [0, 5, 10, muscleMapTopOfScale];

/// A part of the drawing, which is not the same as a muscle: the figure
/// shows a shoulder in three places, and all three stand for the one
/// group the records actually know about.
enum _Region {
  chest(MuscleGroup.chest),
  frontShoulders(MuscleGroup.shoulders),
  rearShoulders(MuscleGroup.shoulders),
  arms(MuscleGroup.arms),
  core(MuscleGroup.core),
  quads(MuscleGroup.quads),
  back(MuscleGroup.back),
  spinalErectors(MuscleGroup.spinalErectors),
  glutes(MuscleGroup.glutes),
  hamstrings(MuscleGroup.hamstrings),
  calves(MuscleGroup.calves);

  const _Region(this.group);

  final MuscleGroup group;
}

/// Front and back figures, shaded by how many working sets each muscle
/// got. The shading answers "where did the work go"; the numbers beside
/// it answer "how much", and neither claims to know about fatigue.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, required this.setsByMuscle});

  /// Weekly working sets per muscle; anything missing is nothing logged.
  final Map<MuscleGroup, int> setsByMuscle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '肌群訓練量人體圖，詳細數值列在下方',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: (_figureWidth * 2 + 12) / _figureHeight,
          child: Row(
            children: [
              for (final isBack in [false, true]) ...[
                if (isBack) const SizedBox(width: 12),
                Expanded(
                  child: CustomPaint(
                    // Without a child a painter has no size of its own.
                    size: Size.infinite,
                    painter: _FigurePainter(
                      setsByMuscle: setsByMuscle,
                      isBack: isBack,
                    ),
                  ),
                ),
              ],
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
  if (sets <= 0) return AppColors.surfaceRaised;
  final t = (sets / muscleMapTopOfScale).clamp(0.0, 1.0);
  return Color.lerp(AppColors.trainingDim, AppColors.training, t)!;
}

class _FigurePainter extends CustomPainter {
  const _FigurePainter({required this.setsByMuscle, required this.isBack});

  final Map<MuscleGroup, int> setsByMuscle;
  final bool isBack;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _figureHeight;
    canvas.save();
    canvas.translate((size.width - _figureWidth * scale) / 2, 0);
    canvas.scale(scale);

    // The body first, in one neutral piece, so the coloured muscles sit
    // on something that reads as a person rather than floating apart.
    final body = Paint()..color = AppColors.surfaceRaised;
    canvas.drawCircle(const Offset(50, 15), 11, body);
    for (final shape in _body) {
      canvas.drawRRect(shape, body);
    }

    for (final (region, shapes) in isBack ? _backShapes : _frontShapes) {
      final paint = Paint()
        ..color = muscleShade(setsByMuscle[region.group] ?? 0);
      for (final shape in shapes) {
        canvas.drawRRect(shape, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.isBack != isBack || !_sameLoad(old.setsByMuscle, setsByMuscle);

  static bool _sameLoad(Map<MuscleGroup, int> a, Map<MuscleGroup, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// The silhouette: neck, torso, arms, legs and feet. Nothing here is
/// coloured by training — it is the shape the muscles sit in.
final _body = <RRect>[
  _r(44, 22, 12, 12, 5), // neck
  _r(33, 30, 34, 40, 12), // chest and upper back
  _r(37, 64, 26, 30, 9), // waist
  _r(37, 88, 26, 16, 8), // hips
  _r(22, 36, 12, 76, 6), // left arm
  _r(66, 36, 12, 76, 6), // right arm
  _r(23, 108, 10, 12, 5), // left hand
  _r(67, 108, 10, 12, 5), // right hand
  _r(37, 96, 12, 100, 6), // left leg
  _r(51, 96, 12, 100, 6), // right leg
  _r(35, 194, 14, 12, 5), // left foot
  _r(51, 194, 14, 12, 5), // right foot
];

RRect _r(double l, double t, double w, double h, [double radius = 4]) =>
    RRect.fromRectXY(Rect.fromLTWH(l, t, w, h), radius, radius);

/// The front of the figure, top down. Left and right are separate
/// shapes, inset from the silhouette so the body still shows around
/// them.
final _frontShapes = <(_Region, List<RRect>)>[
  (_Region.frontShoulders, [_r(27, 32, 15, 15, 7.5), _r(58, 32, 15, 15, 7.5)]),
  (_Region.chest, [_r(37, 38, 12, 16, 5), _r(51, 38, 12, 16, 5)]),
  (_Region.arms, [_r(24, 48, 8, 40, 4), _r(68, 48, 8, 40, 4)]),
  (_Region.core, [_r(41, 58, 18, 28, 6)]),
  (_Region.quads, [_r(39, 100, 8, 50, 4), _r(53, 100, 8, 50, 4)]),
  (_Region.calves, [_r(39, 154, 8, 36, 4), _r(53, 154, 8, 36, 4)]),
];

/// The back of the figure. The shoulders and arms are where they are in
/// front; what changes is what lies between them.
final _backShapes = <(_Region, List<RRect>)>[
  (_Region.rearShoulders, [_r(27, 32, 15, 15, 7.5), _r(58, 32, 15, 15, 7.5)]),
  (_Region.back, [_r(37, 38, 26, 26, 9)]),
  (_Region.arms, [_r(24, 48, 8, 40, 4), _r(68, 48, 8, 40, 4)]),
  (_Region.spinalErectors, [_r(44, 66, 12, 22, 5)]),
  (_Region.glutes, [_r(38, 90, 11, 14, 6), _r(51, 90, 11, 14, 6)]),
  (_Region.hamstrings, [_r(39, 106, 8, 44, 4), _r(53, 106, 8, 44, 4)]),
  (_Region.calves, [_r(39, 154, 8, 36, 4), _r(53, 154, 8, 36, 4)]),
];
