import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app.dart';
import 'app/app_store.dart';
import 'backend/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final backend = await Backend.openOnDevice();
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MishirubeApp(store: AppStore(backend: backend)),
    ),
  );
}
