import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app.dart';
import 'app/app_store.dart';
import 'backend/application/ai_service.dart';
import 'backend/backend.dart';
import 'backend/health/health_source.dart';
import 'backend/seed/catalogue.dart';
import 'backend/seed/exercise_catalogue.dart';
import 'backend/seed/seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final backend = await Backend.openOnDevice();
  // The bundled brand data is refreshed on every launch, so an app
  // update brings the corrections with it. It is safe to replace because
  // it is read-only, and meals logged from it kept their own numbers.
  await loadCatalogue(backend.storage.foods);
  // The demo goes in first, so the library then takes over the exercises
  // the demo also names instead of the demo overwriting them.
  seedDemoData(backend, DateTime.now());
  await loadExerciseCatalogue(backend.db, backend.storage.exercises);
  final store = AppStore(
    backend: backend,
    ai: AiService.onDevice(backend.db),
    health: PlatformHealthSource.forThisDevice(),
  );
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MishirubeApp(store: store),
    ),
  );
  // Apple Health or Health Connect is read again on every launch once
  // connected, so last night is there without asking.
  store.syncHealthInBackground();
}
