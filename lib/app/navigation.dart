import 'package:flutter/material.dart';

import 'app_store.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

/// Full-screen modal (slides up, shows a close button instead of back).
Future<T?> pushModalPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context)
      .push<T>(MaterialPageRoute(builder: (_) => page, fullscreenDialog: true));
}

Future<T?> replaceWithPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context)
      .pushReplacement<T, void>(MaterialPageRoute(builder: (_) => page));
}

/// Closes every pushed page and shows [tab] in the home shell.
void returnToTab(BuildContext context, HomeTab tab) {
  AppStoreScope.read(context).selectTab(tab);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
