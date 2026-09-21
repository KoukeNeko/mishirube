import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

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
  });

  final String brand;

  /// A row for one drink; [refresh] rebuilds this page after the row
  /// changed the plate.
  final Widget Function(FoodItem food, VoidCallback refresh) rowFor;

  /// The opening page's plate bar, or null while the plate is empty.
  final Widget? Function() footer;

  @override
  State<BrandMenuScreen> createState() => _BrandMenuScreenState();
}

class _BrandMenuScreenState extends State<BrandMenuScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final menu = store.menuOf(widget.brand);
    final record = store.catalogues
        .where((catalogue) => catalogue.brand == widget.brand)
        .firstOrNull;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.brand,
        subtitle: '${menu.length} 款 · 官方資料',
      ),
      footer: widget.footer(),
      children: [
        Gutter(
          child: InfoBanner(
            message: [
              '依品牌官網逐筆轉錄，唯讀，不能修改。',
              if (record?.checkedAt case final at?) '查證於 ${formatDate(at)}。',
              '杯型各自有官方數值，不是按比例換算。',
            ].join(''),
          ),
        ),
        for (final food in menu) Gutter(child: widget.rowFor(food, _refresh)),
        Gutter(
          child: const Text(
            '收藏某個杯型：進到那一杯的份量頁，按右上的星號。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
