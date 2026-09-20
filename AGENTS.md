# AGENTS.md

Instructions for AI coding agents working in this repository. The user's
instructions for the current task take precedence. Code, `pubspec.yaml`,
`analysis_options.yaml` and the tests are the source of truth; this file
only records intent that cannot be read from them.

## Project

MISHIRUBE is a local-first Flutter fitness and nutrition logging app (iOS
and Android). Data lives in an on-device SQLite database (`lib/backend/`),
seeded with the design's demo data on first launch; there is no server,
sync, HealthKit or AI integration. The UI is dark, edge-to-edge and built
from custom floating glass chrome rather than stock Material widgets.

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

- `lib/app/` – app root (`app.dart`), theme tokens (`theme.dart`), the
  screen-facing state (`app_store.dart`), navigation helpers.
- `lib/domain/` – the domain model, one file per area (`training.dart`,
  `nutrition.dart`, `body.dart`, `wellness.dart`, `records.dart`,
  `history.dart`), re-exported by `domain.dart`. Domain types hold no
  storage, file or network logic. Plan (`Routine`) and actual
  (`WorkoutSession`) stay separate: editing a template never rewrites a
  finished workout.
- `lib/backend/` – the local-first backend, in layers:
  - `storage/` – `AppDatabase` (SQLite via `package:sqlite3`, migrations in
    `schema.dart`), one repository per area, and `TimelineQuery`.
  - `engines/` – deterministic calculation over domain values only:
    training metrics, trends, insights, nutrition summaries, substitutions.
  - `application/` – the use cases screens work through (`TrainingService`,
    `NutritionService`, `CatalogService`, `JournalService`,
    `InsightsService`).
  - `import_export/` – canonical JSON archive, CSV views, Strong importer.
  - `seed/` – the demo content and the first-launch seed.
- `lib/shared/widgets/` – shared UI; import through `widgets.dart`. Put new
  widgets in the matching folder: `page/` (page frame, app bar, collapsing
  header, footers), `chrome/` (floating glass surfaces), `controls/`
  (buttons, chips, pills, inputs, pickers), `content/` (cards, rows, stats,
  charts, banners).
- `lib/shared/toast/` – app-wide toast host and controller.
- `lib/features/<area>/` – screens per area; `shell/` holds the home shell
  and the floating bottom dock.
- `test/support/harness.dart` – shared test harness (phone viewport with
  iPhone insets, fake clock, `pumpScreen`).

### Where a widget goes

Decide by what the widget knows, not by who uses it first:

- `lib/shared/widgets/<category>/` when it is domain-agnostic: it takes
  plain values and callbacks and carries no feature data, mock data or
  feature-specific wording (e.g. the month pickers, `Pill`, `SelectChip`).
  This holds even while only one feature uses it. A shared widget may take
  a `lib/data` model that several areas display (e.g. `ElapsedClock` with
  `WorkoutSession`).
- `lib/features/<area>/` when it encodes that area's content or data: its
  models, mock data, copy or rules (e.g. `log/month_calendar.dart` with
  record-category dots, `nutrition/split_dish_sheet.dart`). A private
  widget used by one screen stays in that screen's file.
- Moving a widget to `shared/` means stripping feature knowledge from it,
  not copying it; there is still one implementation.
- Inside `lib/shared/widgets/`, import sibling files directly; features
  import `widgets.dart`.

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
  on `Pill` / `pillHeight` so they keep one height, fill and label style.
  A chip that does something on tap is a `ChipButton`, never a `TagChip`
  wrapped in a `GestureDetector`;
- buttons: `PrimaryButton` / `SecondaryButton` / `NutritionButton`,
  `SquareIconButton`, `LinkText` for inline text actions, and
  `AppBarBackButton` for a leading back or collapse control. Do not use a
  bare `TextButton`, `IconButton` or `GestureDetector` as a button in a
  feature;
- dialogs: `AppDialog` shown with `showAppDialog` – the app's own frosted
  dialog, with stacked full-width actions built from the buttons above.
  Do not use `AlertDialog`, `showDialog` or Material dialog buttons;
- state: `AppStore` via `AppStoreScope` (`ChangeNotifier` +
  `InheritedNotifier`). Do not add Provider, Riverpod, Bloc or similar.

## Backend rules

- Keep to the layers: screens talk to `AppStore`, `AppStore` talks to the
  services in `application/`, and only those (plus import/export and the
  seed) talk to `storage/`. Engines take domain values and return values;
  they never read the database.
- The database is the source of truth. `AppStore` keeps what screens show
  in memory and writes every change through a service in the same call; do
  not keep state that must survive a restart only in memory.
- Every write runs in `AppDatabase.transaction` and records an
  `audit_events` row in that transaction. Never hard delete a record:
  set `deleted_at` (tombstone) and bump `revision`.
- Schema changes append a step to `schema.dart`; never edit a released
  step. Update the archive table list in `canonical_archive.dart` in the
  same change, and keep the export → restore → export round trip lossless.
- Usage figures and insights (last performance, record counts, e1RM,
  timeline, calendar, trends) are derived from the records on each read,
  not stored or hard-coded. An engine that cannot support a statement
  returns null so the screen can say there is not enough data.
- Imports go through a dry run first and commit as one undoable batch.
- Nothing is hard deleted and nothing rewrites history: hiding an exercise
  or abandoning a workout keeps the records and the audit trail.

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
- Backend tests run real SQLite, in memory or in a temp file:
  `backend_test.dart` (persistence across restarts, rollback, audit,
  derived history, archive round trip), `strong_import_test.dart`
  (importing) and `engines_test.dart` (engines, search and insights).
- `engine_golden_test.dart` pins what the engines say about the demo
  records. A deliberate rule change bumps that engine's version constant
  and updates `test/golden/engines.txt` in the same commit; an unexpected
  diff means the change reached further than intended.
- `performance_test.dart` keeps the reads quick at 10,000 sets. They run
  on the UI isolate, so a regression there is dropped frames on a phone.
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
