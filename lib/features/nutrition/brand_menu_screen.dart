import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'nutrition_view_model.dart';

/// One chain's menu as it shipped with the app.
///
/// Browsing is the second way in, not the first: most of the time the
/// drink is found by searching. So the page is a plain list with where
/// the figures came from at the top, and the rows behave exactly as they
/// do on the page that opened it — the plate is that page's, and so is
/// every row, built by [rowFor].
class BrandMenuScreen extends StatefulWidget {
  const BrandMenuScreen({
    super.key,
    required this.brand,
    required this.rowFor,
    required this.footer,
    required this.plateChanges,
  });

  final String brand;

  /// A row for one drink; [refresh] rebuilds this page after the row
  /// changed the plate.
  final Widget Function(FoodItem food, VoidCallback refresh) rowFor;

  /// The opening page's plate bar, or null while the plate is empty.
  final Widget? Function() footer;

  /// Fires when the plate changes on a page opened over this one.
  final Listenable plateChanges;

  @override
  State<BrandMenuScreen> createState() => _BrandMenuScreenState();
}

class _BrandMenuScreenState extends State<BrandMenuScreen> {
  late final NutritionViewModel _nutrition;
  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
    widget.plateChanges.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.plateChanges.removeListener(_refresh);
    _nutrition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final store = AppStoreScope.of(context);
    final menu = _nutrition.menuOf(widget.brand);
    final record = store.catalogues
        .where((catalogue) => catalogue.brand == widget.brand)
        .firstOrNull;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.brand,
        subtitle: [
          '${menu.length} 款',
          '官方資料',
          if (record?.checkedAt case final at?) '查證 ${formatDate(at)}',
        ].join(' · '),
      ),
      footer: widget.footer(),
      children: [
        // A chain that sells several lines lists them apart: CITY CAFE's
        // 拿鐵 and 不可思議咖啡's are different drinks.
        for (final (index, food) in menu.indexed) ...[
          if (food.series.isNotEmpty &&
              (index == 0 || menu[index - 1].series != food.series))
            Gutter(child: SectionLabel(food.series)),
          Gutter(child: widget.rowFor(food, _refresh)),
        ],
      ],
    );
  }
}
