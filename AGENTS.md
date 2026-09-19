# AGENTS.md

Instructions for AI coding agents working in this repository. The user's
instructions for the current task take precedence. Code, `pubspec.yaml`,
`analysis_options.yaml` and the tests are the source of truth; this file
only records intent that cannot be read from them.

## Project

MISHIRUBE is a clickable Flutter mock of a fitness and nutrition logging
app (iOS and Android). All data is local mock data (`lib/data/`); there is
no backend, HealthKit or AI integration. The UI is dark, edge-to-edge and
built from custom floating glass chrome rather than stock Material widgets.

## Toolchain

- Use Flutter 3.47.x (Dart ^3.13, see `pubspec.yaml`). Check
  `flutter --version` first: a machine may have an older SDK earlier on
  `PATH`, which fails to resolve dependencies or builds against the wrong
  framework.
- Do not run `flutter upgrade`, switch channels or change SDK constraints
  unless the task asks for it.

## Commands

```sh
flutter pub get
dart format lib test
flutter analyze            # must report "No issues found!"
flutter test               # whole suite
flutter test test/<file>_test.dart
```

## Map

- `lib/app/` – app root (`app.dart`), theme tokens (`theme.dart`), mock state
  (`app_store.dart`), navigation helpers.
- `lib/data/` – domain models and mock data. Plan (`Routine`) and actual
  (`WorkoutSession`) stay separate: editing a template never rewrites a
  finished workout.
- `lib/shared/widgets/` – shared UI; import through `widgets.dart`. Put new
  widgets in the matching folder: `page/` (page frame, app bar, collapsing
  header, footers), `chrome/` (floating glass surfaces), `controls/`
  (buttons, chips, pills, inputs), `content/` (cards, rows, stats, charts,
  banners).
- `lib/shared/toast/` – app-wide toast host and controller.
- `lib/features/<area>/` – screens per area; `shell/` holds the home shell
  and the floating bottom dock.
- `test/support/harness.dart` – shared test harness (phone viewport with
  iPhone insets, fake clock, `pumpScreen`).

## Reuse, don't duplicate

Before adding UI or state, look for an existing implementation and reuse it.
In particular, do not create a parallel version of:

- the page frame: `PageScaffold` / `DetailPage` with `PageAppBar`, or
  `CollapsingPage` for tab roots (collapsing large-title app bar);
- the floating split dock (`lib/features/shell/bottom_chrome/`);
- toasts: `showToast` / `ToastScope.read(context).showUndo` – never
  `SnackBar` or `ScaffoldMessenger`;
- floating footers: `BottomActionBar`;
- pill-shaped controls (header actions, chips, segmented controls): build
  on `Pill` / `pillHeight` so they keep one height, fill and label style;
- state: `AppStore` via `AppStoreScope` (`ChangeNotifier` +
  `InheritedNotifier`). Do not add Provider, Riverpod, Bloc or similar.

## Layout rules

- The app is edge-to-edge. Do not wrap screens in `SafeArea`; the chrome
  that touches a system edge handles that inset itself.
- Page containers add no horizontal padding. Every element on a page spaces
  itself from the screen edges with `Gutter`. Full-bleed elements (e.g.
  horizontal chip rows) skip `Gutter` and pad their own content instead.
- Floating bottom chrome (dock, footers, toasts) uses
  `floatingChromeBottomOffset`; on iOS it dips into the home-indicator area
  like Liquid Glass bars. Do not stack it on top of the full inset.
- Top bar and dock sizes differ per platform (`ToolbarMetrics`,
  `DockMetrics`). Keep platform differences inside those metrics instead of
  scattering platform checks.
- Use tokens from `lib/app/theme.dart` (`AppColors`, `AppSpacing`,
  `AppRadius`, `AppTextStyles`) rather than raw values.

## Accessibility

- Custom controls need semantics labels and must report selected state.
- Touch targets: at least 44pt on iOS, 48dp on Android.
- Honour reduced motion with `prefersReducedMotion` / `chromeDuration`
  (`lib/shared/motion.dart`). iOS reports Reduce Motion separately from
  `MediaQuery.disableAnimations`, so do not read that flag directly.
- Layout must survive large text: measure text instead of hard-coding
  heights that contain it.

## Native folders

Do not change `ios/` or `android/` configuration (bundle identifier,
signing team, deployment targets, Gradle, Podfile, permissions) unless the
task requires it.

## Testing

- `test/screens_smoke_test.dart`: every screen renders without layout
  errors and uses the shared app bar (the rest timer is the only listed
  exception).
- Flow tests (`flows_test.dart`) cover multi-step user journeys.
- Geometry tests (`chrome_geometry_test.dart`, `edge_to_edge_test.dart`,
  `collapsing_header_test.dart`, `toast_test.dart`) pin layout contracts.
  When you change the dock, app bar, footers, toasts or insets, update or
  add a geometry test that states the intended invariant.
- Use `pumpScreen` / `usePhoneViewport` from the harness, and end widget
  tests with `disposeTree` so clocks and timers are cleaned up.
- Never weaken or delete a test just to make it pass.

## Done means

1. `dart format` on the changed files.
2. `flutter analyze` with no issues.
3. The relevant tests, then the full `flutter test`.
4. Review the diff for unrelated changes.

If a check cannot run, say so instead of claiming it passed.

## Git

- Conventional Commits: `<type>(<scope>): <imperative summary>` with types
  `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`,
  `revert`. One reviewable intent per commit.
- Commits must be signed with the configured key (`git commit -S`); verify
  with `git log --format='%h %G? %s'`.
- No AI or tool attribution in commits, PRs or repository content.
- Do not commit or push unless asked.
