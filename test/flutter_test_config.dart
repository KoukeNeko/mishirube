import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Every test reads the app in the language it was written in, whatever
/// language the machine running it is set to: the whole app follows the
/// system's language, and the screens under test follow [testLocale].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localesTestValue = const <Locale>[testLocale];
  await testMain();
}
