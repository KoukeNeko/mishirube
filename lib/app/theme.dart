import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Color tokens taken from the MISHIRUBE design mock (dark only).
abstract final class AppColors {
  static const background = Color(0xFF0F1110);
  static const surface = Color(0xFF1A1C1B);
  static const surfaceRaised = Color(0xFF242726);

  /// The glass of the top bar's buttons (see `barControlTintOpacity`): a
  /// light veil, as iOS draws them in dark mode, so what lies under them
  /// (a map, the page) shows through instead of a dark disc.
  static const barControl = Color(0xFFFFFFFF);
  static const outline = Color(0xFF2C302E);

  static const textPrimary = Color(0xFFF2F3F1);
  static const textSecondary = Color(0xFFA3A7A5);
  static const textTertiary = Color(0xFF6E7371);

  static const training = Color(0xFF2EE09A);
  static const trainingDim = Color(0xFF1A5A43);
  static const trainingSurface = Color(0xFF10261E);
  static const trainingOutline = Color(0xFF1E4A3A);
  static const onTraining = Color(0xFF06140E);

  static const nutrition = Color(0xFFE5672B);
  static const nutritionSurface = Color(0xFF2A1911);
  static const nutritionOutline = Color(0xFF5B2F1A);

  static const body = Color(0xFF5B8DEF);

  /// Water: a sky blue, apart from 飲食's orange, the body's deeper
  /// blue, activity's cyan and the sugar alcohols' pale blue (CIEDE2000
  /// at least 11 from each accent).
  static const water = Color(0xFF2FA8E6);

  /// Caffeine: a roasted coffee bean's brown, lifted to 5:1 on a card
  /// and kept apart from 飲食's orange beside it on Today (CIEDE2000 18).
  static const caffeine = Color(0xFFA58566);
  static const wellness = Color(0xFF8C7CF4);
  static const wellnessSurface = Color(0xFF1B1830);
  static const wellnessOutline = Color(0xFF39336B);

  /// General exercise: far enough from the training green to tell a run
  /// from a workout at a glance.
  static const activity = Color(0xFF3FD0D6);
  static const activitySurface = Color(0xFF0E2427);
  static const activityOutline = Color(0xFF1B4448);

  /// The heart and the vitals, wherever they are drawn: the pink Apple
  /// Health gives both, kept apart from [destructive] (ΔE2000 16) so a
  /// chart never reads as a warning (see `research/86-color-allocation.md`).
  static const heart = Color(0xFFFF5F83);

  /// Breathing and blood oxygen: Apple Health's respiratory cyan, apart
  /// from activity's cyan and the water blue (CIEDE2000 at least 11).
  static const breathing = Color(0xFF3DD3FE);

  /// Losing data for good. Amber is a caution; this is the one that says
  /// something will not come back.
  static const destructive = Color(0xFFFF453A);

  static const warning = Color(0xFFE8B94A);

  // The three macronutrients, told apart wherever they sit side by side.
  static const macroCarb = Color(0xFFF2C66D);
  static const macroProtein = Color(0xFFEF7B5C);
  static const macroFat = Color(0xFF7BD6A0);

  /// What else carries energy beside them: fibre and sugar alcohols
  /// inside the carbohydrate, and alcohol.
  static const macroFibre = Color(0xFFB39DDB);
  static const macroPolyols = Color(0xFF8CC8E8);
  static const macroAlcohol = Color(0xFFD98BC4);
  static const warningSurface = Color(0xFF2A2412);
  static const warningOutline = Color(0xFF5A4A1E);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const screenGutter = 20.0;
}

abstract final class AppRadius {
  static const chip = 999.0;
  static const small = 12.0;
  static const card = 20.0;
  static const button = 18.0;
}

abstract final class AppTextStyles {
  static const _numberFeatures = [FontFeature.tabularFigures()];

  static const screenTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  static const cardTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );
  static const itemTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
    height: 1.6,
  );
  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );
  static const bigNumber = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    fontFeatures: _numberFeatures,
  );
  static const hugeNumber = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -1,
    fontFeatures: _numberFeatures,
  );
  static const buttonLabel = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );
}

/// Transparent system bars with light icons, so the dark UI runs edge to edge.
const appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.training,
    onPrimary: AppColors.onTraining,
    secondary: AppColors.nutrition,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.nutrition,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.training,
    ),
  );
}
