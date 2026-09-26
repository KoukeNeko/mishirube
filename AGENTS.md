# AGENTS.md

Instructions for AI coding agents working in this repository. The user's
instructions for the current task take precedence. Code, `pubspec.yaml`,
`analysis_options.yaml` and the tests are the source of truth; this file
only records intent that cannot be read from them.

## Project

MISHIRUBE is a local-first Flutter fitness and nutrition logging app (iOS
and Android). Data lives in an on-device SQLite database (`lib/backend/`),
seeded with the design's demo data on first launch; there is no server
or sync. Sleep, weight, waist, body composition, workouts, water and
everyday activity (steps, energy, heart and fitness figures) can be
read, never written, from Apple Health (iOS) or Health Connect
(Android). AI is
optional and only drafts or words figures the app already worked out:
Apple's on-device model, used without asking whenever Apple
Intelligence is on and nothing else was chosen, or a cloud provider
with the user's own key (Ollama Cloud, Google AI Studio, Anthropic,
Azure AI Foundry, or any OpenAI-compatible address), or Microsoft 365
Copilot signed in to, and nothing a model returns is logged
until the user confirms it. The UI is dark, edge-to-edge and built from custom
floating glass chrome rather than stock Material widgets.

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
  - `ai/` – the AI providers (`MealDrafter`, cloud ones sharing
    `CloudDrafter`) and the keychain-backed `SecretStore`. A provider returns a draft and holds no repository;
    `AiService` in `application/` chooses one, and writing a confirmed
    draft is `NutritionService`'s job. Not an engine: model output is
    not deterministic.
  - `health/` – `HealthSource`: Apple Health through
    `ios/Runner/AppDelegate.swift`, Health Connect through
    `android/.../HealthConnectBridge.kt`, both answering the same channel
    calls. `HealthService` imports what they read with ids derived from
    the platform's (a night from its morning, via
    `engines/sleep_nights.dart`), so a re-read never duplicates and a
    deleted record never returns.
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
- page sections: a `SectionLabel` and its items as the page's own
  children, which the page spaces by `pageItemSpacing`; a section built as
  one widget is a `PageSection`. Never put a `SectionLabel` and its items
  in a plain `Column`, which drops that spacing;
- list rows: `NavRow` (in a `GroupedCard`) or `NavCard` (an item on its
  own card) – leading marker, title with an optional mark, subtitle, a
  quieter detail line, and a trailing value or control. Do not lay out a
  title-and-subtitle row by hand. The chevron means "opens a page": a row
  whose tap selects or toggles sets `showChevron: false`. Selection
  markers follow what is being chosen: `RadioDot` (or `RadioRow`) for one,
  `CheckSquare` (or `CheckRow`) for several, and a numbered badge only
  where the order is the answer (the exercise picker). A list that picks
  nothing shows no marker at all. A setting that is on or off is a
  `SwitchRow`, changed in place, not a row that opens or closes a page;
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
  dialog. Choices are `DialogAction`s with a `DialogTone`, drawn as rows
  separated by hairlines, not as buttons: the accent stays on one label
  instead of a slab of colour. Two labels that fit sit side by side (the
  way out leading), anything else stacks, and the dialog decides that by
  measuring, never by counting characters. A dialog that asks for one
  line of text is `showTextDialog`, which owns the controller. Do not use
  `AlertDialog` or `showDialog`;
- state: a feature's screen owns a `ViewModel` (`lib/app/view_model.dart`,
  a `ChangeNotifier` over `Backend`) in `features/<area>/<area>_view_model.dart`,
  creates it in its `State`, disposes it with itself and rebuilds with
  `ListenableBuilder`; widgets below it get the view model passed in. A
  view model rebuilds on `AppDatabase.changes`, which fires after every
  committed write, so screens never tell each other what changed.
  `AppStore` via `AppStoreScope` holds only state of the app as a whole
  (onboarding, modules, the selected tab, the running session) and the
  features not yet moved to a view model; do not add feature state to it.
  Do not add Provider, Riverpod, Bloc or similar.

## Backend rules

- Keep to the layers: screens talk to their view model (or `AppStore`),
  those talk to the services in `application/`, and only the services
  (plus import/export and the seed) talk to `storage/`. Engines take domain values and return values;
  they never read the database.
- The database is the source of truth. A view model or `AppStore` reads
  what a screen shows from the services and writes every change through a
  service in the same call. Do not keep a second copy of stored records in
  memory: at most cache a read until the next `AppDatabase.changes`. Do
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
- Window sizes are decided in `lib/shared/window_layout.dart` and nowhere
  else: from 840dp, or on any foldable opened like a book (the panes then
  meet at the fold), every tab is a main page on the leading side
  (`mainPaneWidthFor`: 40% of the window, within 360–480) with what is
  opened from it beside it, and a page's content column is its pane,
  inside the safe area and on one side of a hinge or bent fold. The dock
  floats
  along the bottom of the main page where a phone has it, never across
  the window and never as a side rail. Decide by the window, never the
  device, and derive the layout on every build rather than storing a
  "tablet mode".
- Pages stay as wide as the window; `Gutter` keeps an element to the
  column (`PageColumn`). A row that scrolls sideways runs edge to edge and
  pads its content by `PageColumn.gutterOf`, so it still leaves the screen.
- Every pane has the same side margin, the `AppSpacing.screenGutter`
  `Gutter` adds, and the content column is never capped or centred:
  cards, lists and charts use the pane's width, as a split view's detail
  column does on iPad. Only footer buttons keep to
  `readableMaxWidth`, as would a paragraph of prose if a page had one.
  A wide pane shows more, not more margin: a group
  of tiles adds columns when it has room (the trends summary), measured
  with `LayoutBuilder`, never by device or orientation.
- Card content sits `AppSpacing.md` in from the card's edge, the
  `AppCard` default and the inset of rows in a `GroupedCard`. Do not pass
  another padding for an ordinary card.
- Never size a page element from `MediaQuery.sizeOf`: in a list pane or
  beside a fold a page element has less room than the window.
  Measure the space it is given (`LayoutBuilder`, `ToolbarWidth`).
- A list whose rows open pages goes in `ListDetailLayout`; its rows keep
  calling `pushPage`, which opens them in the pane when there is one.
- With two panes nothing a user opens covers the whole window. Open pages
  with `pushPage`, never `Navigator.push` with a `MaterialPageRoute`.
  What is opened from outside a tab's list (the dock, the add menu, a
  session's finish dialog) goes through `HomeShell`'s opener, which uses
  `ListDetailLayoutState.showBeside`. `pushModalPage` is only for pages
  opened from a page that is already open, where it stays in that page's
  navigator; a tab's list uses `pushPage`. Sheets and `showAppDialog`
  already open in the navigator they are called from. The only
  full-window pages are onboarding and a system request (the health
  privacy page). `test/adaptive_layout_test.dart` pins each entry point;
  add one there for a new way in.
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

## UI copy

Words on screen follow `research/19-glossary.md`: one concept, one
term. On top of that, three rules. When unsure, write less: deleting a
sentence is almost always better than rewording it.

1. **Labels and states are nouns or short states.** Section labels,
   row titles, subtitles, chips, stat labels and empty states name the
   thing or its state: `服務`, `未設定`, `已暫停`, `沒有紀錄`,
   `3 天前`. Do not address the reader (`你`, `你的`), do not say
   `還沒` (use `未` or `沒有`), do not ask questions (`用哪一個`,
   `這是吃的還是喝的`), and do not coach, motivate or reassure
   (`休息也是訓練的一部分`, `之後隨時可以調整`).
2. **Explanations only where the user decides.** A sentence that
   explains belongs in a dialog that asks for a choice, a destructive
   confirmation, a warning (`InfoBanner` with `CardTone.warning`) or an
   error. Nowhere else: no footnote captions under sections or forms,
   no banners restating how the page works, no gesture hints ("點一項
   可以…", "往左滑…"), no design rationale ("條件之間可以自由組合"),
   no "這裡會…" promises in empty states. A value that needs a qualifier
   gets a short tag (`Epley 估計`, `依半衰期 5 小時推算`), not a
   paragraph, and says it once: `估計` already means not measured, so
   no `，非實測` after it. Keep a warning to the risk and what to do about it, and
   put a field's instructions in that field's dialog hint.
   Don't put into words what a figure or its layout already says: no
   `約` before a worked-out or estimated number (`140 kcal`, not
   `約 140 kcal`), and no `上限` or `目標` after a slash that already
   makes the second number one (`128 / 2,400 mg`).
3. **Privacy and storage are explained once, on the privacy page**
   (`lib/features/me/privacy_screen.dart`). Other screens do not repeat
   that data stays on the device, what AI receives, where keys are kept
   or that nothing is uploaded. The cloud-AI consent dialog is the one
   exception, because it is the decision.

Also:

- Units are symbols (`kg`, `cm`, `km`, `mL`, `m`) in values and
  sentences alike; minutes are `分`. Dates read `9 月 19 日（週六）`,
  parts are joined with ` · `.
- Say "device", not "phone" (`這台裝置`, `iOS`): the app runs on iPad
  too.
- A button or destructive action names its object (`刪除這份模板`,
  `撤回同意`), per the glossary.
- A string shown only to a screen reader follows the same rules.

`test/copy_test.dart` fails on `你` or `還沒` in any string under
`lib/` (AI prompts and seed data excepted). The other rules are for
review: read every new string against them before finishing.

## Native folders

Do not change `ios/` or `android/` configuration (bundle identifier,
signing team, deployment targets, Gradle, Podfile, permissions) unless the
task requires it.

## Testing

- `test/screens_smoke_test.dart`: every screen renders without layout
  errors and uses the shared app bar (the camera is the only listed
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
  `collapsing_header_test.dart`, `toast_test.dart`,
  `adaptive_layout_test.dart`) pin layout contracts. The smoke test runs
  every screen on a phone, a phone on its side and a tablet.
  When you change the dock, app bar, footers, toasts or insets, update or
  add a geometry test that states the intended invariant.
- `secrets_test.dart` scans the source for credential-shaped literals
  and proves nothing secret rides out in an archive, a CSV view or the
  audit trail. Settings under `AppDatabase.secretKeyPrefix` are never
  exported and never deleted by a restore.
- Use `pumpScreen` / `usePhoneViewport` from the harness, and end widget
  tests with `disposeTree` so clocks and timers are cleaned up.
- Never weaken or delete a test just to make it pass.

### Fixtures, snapshots and corpora

- Fixtures are built in the test that uses them, from the domain types,
  not loaded from checked-in files. A fixture that drifts from the model
  fails to compile, which is the point.
- The demo content in `lib/backend/seed/` is the app's own data, not a
  fixture. Tests may read it; they must not edit it to make an
  assertion pass.
- Snapshots live in `test/golden/` as text, one file per thing pinned.
  They are regenerated by the test that reads them, never by hand, and a
  deliberate change updates the snapshot in the same commit as the code.
  An unexplained snapshot diff is a finding, not a chore.
- Import corpora are literals inside `strong_import_test.dart`: a real
  export from another app is somebody's training history, and it does
  not belong in this repository. A new importer builds its sample rows
  the same way.
- A bug found in an import gets the row that caused it added to that
  file, with what went wrong beside it.

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
