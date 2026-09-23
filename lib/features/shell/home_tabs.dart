import 'package:flutter/material.dart';

import '../../app/app_store.dart';

/// How a tab is drawn, wherever the tabs are: the dock or the rail.
class HomeTabSpec {
  const HomeTabSpec(this.tab, this.icon, this.selectedIcon, this.label);

  final HomeTab tab;
  final IconData icon;

  /// Filled variant, so selection is not signalled by colour alone.
  final IconData selectedIcon;
  final String label;
}

/// The tabs in [HomeTab] order.
const homeTabs = [
  HomeTabSpec(
    HomeTab.today,
    Icons.my_location_outlined,
    Icons.my_location,
    '今天',
  ),
  HomeTabSpec(HomeTab.log, Icons.list_alt_outlined, Icons.list_alt, '紀錄'),
  HomeTabSpec(HomeTab.trends, Icons.insights_outlined, Icons.insights, '趨勢'),
  HomeTabSpec(HomeTab.me, Icons.person_outline, Icons.person, '我的'),
];
