// A look at the segmented groups Today could be made of, with sample
// figures and no app around them:
//
//   flutter run -t tool/preview_today.dart -d <device>
import 'package:flutter/material.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 48),
        children: [
          const Text('今天', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.lg),
          ..._groups(),
          const SizedBox(height: AppSpacing.xl),
          const Text('沒有紀錄', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.sm),
          ..._empty(),
          const SizedBox(height: AppSpacing.xl),
          const Text('寬 320 pt 的手機', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: SizedBox(width: 280, child: Column(children: _narrow())),
          ),
        ],
      ),
    ),
  );
}

Widget _icon(IconData icon, Color tint) => Icon(icon, size: 16, color: tint);

Widget _dot(Color tint) => DecoratedBox(
  decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
  child: const SizedBox.square(dimension: 8),
);

Segment _macro(String name, String grams, Color color) => Segment(
  onTap: () {},
  child: SegmentStat(
    label: name,
    color: color,
    mark: _dot,
    placeholder: '—',
    value: grams,
    unit: 'g',
    valueSize: 20,
  ),
);

Segment _sleep({String? value}) => Segment(
  onTap: () {},
  child: SegmentStat(
    label: '睡眠',
    color: AppColors.wellness,
    mark: (tint) => _icon(Icons.bedtime_outlined, tint),
    placeholder: '沒有紀錄',
    value: value,
    caption: value == null ? null : '含小睡共 8 小時 40 分',
  ),
);

Segment _bath({bool isEmpty = false}) => Segment(
  onTap: () {},
  child: SegmentStat(
    label: '洗澡',
    color: AppColors.wellness,
    mark: (tint) => _icon(Icons.bathtub_outlined, tint),
    placeholder: '沒有紀錄',
    value: isEmpty ? null : '22:10',
    unit: isEmpty ? null : '溫水 · 浴缸',
  ),
);

Segment _weight({bool isEmpty = false}) => Segment(
  onTap: () {},
  child: SegmentStat(
    label: '體重',
    color: AppColors.body,
    mark: (tint) => _icon(Icons.monitor_weight_outlined, tint),
    placeholder: '沒有紀錄',
    value: isEmpty ? null : '72.4',
    unit: isEmpty ? null : 'kg',
    caption: isEmpty ? null : '7 日 −0.4',
  ),
);

Segment _water({bool isEmpty = false}) => Segment(
  onTap: () {},
  background: isEmpty
      ? null
      : const LevelFill(level: 0.66, color: AppColors.water),
  child: SegmentStat(
    label: '喝水',
    color: AppColors.water,
    mark: (tint) => _icon(Icons.water_drop_outlined, tint),
    placeholder: '沒有紀錄',
    value: isEmpty ? null : '1,000',
    unit: isEmpty ? null : '/ 1,500 mL',
    caption: isEmpty ? null : '3 次',
  ),
);

List<Widget> _groups() => [
  CategoryGroup(
    label: '飲食',
    color: AppColors.nutrition,
    tag: const TagChip(label: '含估計值', tone: TagTone.nutrition),
    children: [
      SegmentedGroup(
        rows: [
          [
            Segment(
              onTap: () {},
              surface: AppColors.surfaceRaised,
              child: const SegmentHero(
                label: '3 餐',
                color: AppColors.nutrition,
                value: '2,184',
                unit: '/ 2,900 kcal',
                progress: 0.753,
              ),
            ),
          ],
          [
            _macro('蛋白質', '98', AppColors.macroProtein),
            _macro('碳水化合物', '240', AppColors.macroCarb),
          ],
          [
            _macro('脂肪', '71', AppColors.macroFat),
            _macro('膳食纖維', '26', AppColors.macroFibre),
          ],
          [_water()],
        ],
      ),
    ],
  ),
  const SizedBox(height: AppSpacing.md),
  CategoryGroup(
    label: '睡眠',
    color: AppColors.wellness,
    children: [
      SegmentedGroup(
        rows: [
          [_sleep(value: '7 小時 45 分'), _bath()],
        ],
      ),
    ],
  ),
  const SizedBox(height: AppSpacing.md),
  CategoryGroup(
    label: '身體',
    color: AppColors.body,
    children: [
      SegmentedGroup(
        rows: [
          [_weight()],
        ],
      ),
    ],
  ),
];

List<Widget> _empty() => [
  CategoryGroup(
    label: '睡眠',
    color: AppColors.wellness,
    children: [
      SegmentedGroup(
        rows: [
          [_sleep(), _bath(isEmpty: true)],
        ],
      ),
    ],
  ),
  const SizedBox(height: AppSpacing.md),
  CategoryGroup(
    label: '身體',
    color: AppColors.body,
    children: [
      SegmentedGroup(
        rows: [
          [_weight(isEmpty: true)],
          [_water(isEmpty: true)],
        ],
      ),
    ],
  ),
];

List<Widget> _narrow() => [
  CategoryGroup(
    label: '睡眠',
    color: AppColors.wellness,
    children: [
      SegmentedGroup(
        rows: [
          [_sleep(value: '7 小時 45 分'), _bath()],
        ],
      ),
    ],
  ),
  const SizedBox(height: AppSpacing.md),
  CategoryGroup(
    label: '飲食',
    color: AppColors.nutrition,
    children: [
      SegmentedGroup(
        rows: [
          [
            _macro('蛋白質', '98', AppColors.macroProtein),
            _macro('碳水化合物', '240', AppColors.macroCarb),
          ],
        ],
      ),
    ],
  ),
];
