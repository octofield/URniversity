# URniversity

A Flutter app (Android, web, desktop) that keeps track of a college student's life: tasks,
semester targets, future visions, journals, timetable and grades, synced through Supabase.
For the structure and setup, read `README.md` when needed.

- **Reply in Traditional Chinese**, whatever language the user writes in.
- The Flutter project is in `src/`; run Flutter commands from there.

## Commands

```bash
cd src
flutter analyze                       # must report no issues
flutter test                          # the whole suite; one file: flutter test test/x_test.dart
flutter build web --release
flutter build apk --debug             # after any Android or plugin change
python scripts/style_assets/generate.py   # from the repo root, after changing a palette
```

- Python tests for the catalog script: `python -m pytest scripts/catalog` (from the repo root).
- **IMPORTANT: never run `dart format`.** It rewrites whole files and buries the real change.
  Hand-edit indentation, only on lines you touched.
- SQL under `supabase/` is run by the user by hand in the Supabase SQL Editor: write it, say which
  file to run, never assume it has been run.
- Never read `scripts/catalog/.env` (it holds the service role key).
- Commit only when asked. Never stage line-ending-only changes in `src/linux`, `src/macos` or
  `src/windows`.

## The docs are the source of truth

Read these before reasoning from code alone, and update them **in the same change**:

| Changing | Update |
|---|---|
| Persisted data: a Supabase column, a SharedPreferences key, a model field, a provider's read/write flow | `docs/data_dictionary.md` and `docs/data_flow_diagram.md` |
| Navigation, input/output formats, an algorithm or flowchart | `docs/system_design.md`, redrawing the affected Mermaid chart |
| Anything tested | a test plan: copy `docs/test-plans/TEMPLATE.md` to `docs/test-plans/YYYY-MM-DD-topic.md`, fill it in before testing, record results after; add the test's row to `docs/testing.md` |

Purely cosmetic changes (styling, spacing, copy) need no doc update. Test cases come from
`docs/testing.md` and the three docs above, not from assumptions.

## How to work

- State assumptions; when a request has several readings, ask instead of picking silently.
- The smallest change that does the job: no speculative features, options or abstractions.
- Touch only what the request needs. Match the surrounding style; mention unrelated dead code
  rather than deleting it; remove only the orphans your change created.
- Turn a task into a check: reproduce a bug with a failing test, then make it pass; for
  multi-step work, list each step with how it will be verified.
- A layout rule that matters is tested at 360, 768 and 1280 wide (`setViewWidth()`).
- Comments are in English, start with a capital and have no trailing period.

## Established patterns

**Before writing a helper, check whether one already exists.** A 2026-08 refactor collapsed
dozens of near-duplicates into these; re-implementing them undoes that work.

| Need | Use | Where |
|---|---|---|
| Delete confirmation dialog | `confirmDelete(context, s)` | `widgets/confirm_dialog.dart` |
| Confirming a non-destructive action | `confirmAction(context, message:, action:)` | `widgets/confirm_dialog.dart` |
| A page opened on top of another (pull down / swipe right to close) | wrap its `Scaffold` in `AppPage`; push it with `AppPageRoute` | `widgets/app_page.dart` |
| A semester's first day of classes | `editTermStart(context, ref, semester)` | `widgets/term_dialog.dart` |
| Open a bottom sheet | `showAppSheet()` wrapping a `SheetBody` | `widgets/sheet_body.dart` |
| Cap a single-column screen on desktop | `ResponsiveBody` | `widgets/responsive_body.dart` |
| Drag-reorder drop zones and ordering | `dropZoneFor()`, `orderBetween()` | `widgets/drag_reorder.dart` |
| A new list-shaped provider | extend `SyncedListNotifier<T>` | `providers/synced_list_notifier.dart` |
| A single-row read from Supabase | `readWithRetry(() => …maybeSingle())` | `providers/synced_list_notifier.dart` |
| Syncing now, or pulling a tab to sync | `liveSyncProvider`'s `refreshAll()`, `PullToSync`, `SyncNowTile` | `providers/realtime_sync.dart`, `widgets/sync_controls.dart` |
| Current account's display name / avatar | `displayIdentityProvider` | `providers/profile_provider.dart` |
| `—` `→` ` · ` placeholders | `kEmptyValue`, `kArrow`, `kDotSeparator` | `core/ui_symbols.dart` |
| Pumping a screen in a widget test | `setUpTestSupabase()`, `pumpScreen()`, `pumpApp()` | `test/helpers/pump_app.dart` |
| Animation duration / curve (never a bare ms number) | `AppMotion`, `scaled()`, `motionScale()` | `core/theme/app_motion.dart` |
| Rows that arrive and leave in a list | `AnimatedRows` | `widgets/animated_rows.dart` |
| A heading whose count changes | `FlipText` | `widgets/flip_text.dart` |
| A card that opens its detail page | `ExpandingCard` | `widgets/expanding_card.dart` |
| A vibration | `haptic(ref, HapticKind.…)` | `core/haptics.dart` |
| Colours, corner radii of the current style | `AppColors`, `AppRadius` | `core/theme/app_colors.dart`, `app_radius.dart` |
| Width breakpoints | `AppBreakpoints.desktop` / `.wide` | `core/theme/app_breakpoints.dart` |
| Opening a page that has an address | `openPage(context, AppRoutes.x, () => const XScreen())` | `core/app_routes.dart` |
| Whether a switchable feature is on (admin backend) | `ref.watch(featureOnProvider('key'))`, keys in `kRemoteFeatures` | `providers/remote_config_provider.dart` |
| The task views' order | `kTaskViewOrder` (stored values 0 all, 1 day, 2 week, 3 courses) | `providers/tasks_provider.dart` |

## Rules that apply everywhere

1. **Never write `catchError((_) {})` or `catch (_) {}` around a write.** Route failures through
   `reportSyncError(ref, e)` so the UI can surface them. A parse fallback is the one exception,
   and it needs a comment saying so.
2. **Colours come only from `AppColors`, radii only from `AppRadius`** — no `Color(0x…)` in
   screens. Course, category and avatar colours are the user's data and the same in every style.
3. **No bare `fontSize:`.** Use a `Theme.of(context).textTheme.*` role; if none matches, keep it
   inline with one comment saying why.
4. **Declare sheet state outside the `showAppSheet` `builder:`.** Flutter re-runs that builder on
   any MediaQuery change (the keyboard alone does it), so state declared inside is silently reset
   — the symptom is "tapping does nothing, I have to press it several times".
5. **User-visible text goes through l10n**, four files at once (see `.claude/rules/l10n.md`).
6. **Every screen is responsive, animated and styled by the rules** in `.claude/rules/` —
   part of "done", not polish for later.

Topic rules load with the files they cover (`.claude/rules/`): `responsive-motion.md` (screens and
widgets), `styles.md` (themes, Android assets), `routes.md` (the router), `sync-and-data.md`
(providers, models, SQL), `testing.md` (tests), `catalog.md` (course catalogs), `l10n.md` (strings).
