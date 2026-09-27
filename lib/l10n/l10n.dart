import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'dates.dart';
export 'labels.dart';

/// The app's strings in the language the system chose for it.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The app's strings in the system's language, for what runs before any
/// screen is built. The language cannot change under it: changing an
/// app's language relaunches it.
AppLocalizations systemLocalizations() => lookupAppLocalizations(
  basicLocaleListResolution(
    WidgetsBinding.instance.platformDispatcher.locales,
    AppLocalizations.supportedLocales,
  ),
);
