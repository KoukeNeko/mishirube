import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app_store.dart';
import 'app/startup.dart';
import 'backend/application/ai_service.dart';
import 'backend/application/exercise_gifs.dart';
import 'backend/backend.dart';
import 'backend/health/health_source.dart';
import 'backend/seed/catalogue.dart';
import 'backend/seed/exercise_catalogue.dart';
import 'backend/seed/packaged_foods.dart';
import 'backend/seed/seed.dart';
import 'backend/storage/database.dart';
import 'backend/storage/database_diagnostics.dart';
import 'backend/storage/storage_access.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android hands touches over at the digitiser's own rate, not the
  // display's, so a scroll's positions fall unevenly between frames and
  // it stutters however many frames are drawn. Resampling reads them at
  // the frame's time instead. iOS already delivers them per frame.
  if (defaultTargetPlatform == TargetPlatform.android) {
    GestureBinding.instance.resamplingEnabled = true;
  }
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  registerPackagedFoodLicences();
  registerExerciseDemoLicences();
  final access = StorageAccess.instance;
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: AppStartup(
        storageAccess: access,
        openStore: () => _openStore(access),
        onReady: _startServices,
      ),
    ),
  );
}

Future<AppStore> _openStore(StorageAccess access) async {
  await DatabaseDiagnostics.readAppInfo();
  final backend = await Backend.openOnDevice(storageAccess: access);
  try {
    // The bundled brand data is read again whenever its files change, so an
    // app update brings the corrections with it. It is safe to replace
    // because it is read-only, and meals logged from it kept their own
    // numbers.
    await loadCatalogue(backend.db, backend.storage.foods);
    // The demo goes in first, so the library then takes over the exercises
    // the demo also names instead of the demo overwriting them. A new
    // install starts with its own records only: the demo stays in the
    // store, hidden, for 我的 → 資料 to show (research/81, item 1).
    if (seedDemoData(backend, DateTime.now())) {
      backend.provenance.setShowsDemo(false);
    }
    await loadExerciseCatalogue(backend.db, backend.storage.exercises);
    final store = AppStore(
      backend: backend,
      ai: AiService.onDevice(backend.db),
      health: PlatformHealthSource.forThisDevice(),
      motion: SensorDeviceMotion(),
      gifs: await ExerciseGifs.onDevice(),
    );
    DatabaseDiagnostics(File(backend.db.path!).parent)
        .resolved(context: 'startup');
    return store;
  } catch (error, stack) {
    backend.close();
    Error.throwWithStackTrace(
      DatabaseOpenFailure.from(
        error,
        stack,
        stage: DatabaseOpenStage.initialization,
        existingFile: true,
      ),
      stack,
    );
  }
}

void _startServices(AppStore store) {
  // Only food search reads the packaged foods, and nobody searches before
  // the first screen is up, so reading them waits for it.
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) async {
      store.backend.nutrition.packagedFoods = await PackagedFoods.load();
    }),
  );
  // Apple Health or Health Connect is read again on every launch once
  // connected, so last night is there without asking, and again each
  // time the app comes back to the front: a phone keeps it running in
  // between, so that is what most openings are. What was logged is
  // written there then too, and as the app leaves the front.
  store.syncHealthInBackground();
  store.refreshOnDeviceAi();
  store.refreshFirstWeekday();
}
