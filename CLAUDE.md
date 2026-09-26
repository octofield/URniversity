## 0. General
- This is an app-developing project named URniversity, managing to keep track of students' lives in college. I hope people can use this app to form a better imagination about the future, or at least organize their daily or semester lives. For any questions or structures, read **README.md**.  
- Use **Traditional Chinese** to response, no matter the user uses English or Chinese.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Coding Style
- Braces: Use the K&R style (do not start curly braces on a new line).
- Parentheses: No space before opening parentheses.
- Spacing: Insert a space between operators and operands.
- Naming: Variables should follow the lowerCamelCase convention.
- Spacing: Use blank lines to separate functions and logical segments.
- Comments: Comments must be in English, capitalized, and have no trailing periods.

## 6. Data Documentation Sync

**`docs/data_flow_diagram.md` (Data Flow Diagram) and `docs/data_dictionary.md` (Data Dictionary) are the source of truth for persisted data.**

- Before reading or reasoning about how data is stored, loaded, or flows between the app and
  Supabase / SharedPreferences, consult `docs/data_flow_diagram.md` and `docs/data_dictionary.md` first instead of
  re-deriving it from provider code alone.
- Whenever you change persisted data — adding/removing/renaming a Supabase table column, a
  SharedPreferences key, a model field, or the read/write flow of a Provider in
  `src/lib/providers/` — update `docs/data_flow_diagram.md` and `docs/data_dictionary.md` in the same change so they stay
  accurate. Treat this as part of the task, not a follow-up.
- If a change is UI-only and touches no persisted field or data flow, no doc update is needed.

## 7. System Design Sync

**`docs/system_design.md` is the source of truth for system behavior: screen navigation, input/output
formats, core algorithms, operation steps, and program flowcharts.**

- Before implementing or reasoning about a screen flow, an algorithm (recurrence matching, tree
  reparenting, semester calculation, responsive breakpoints, graph layout, etc.), or a use case,
  consult `docs/system_design.md` first instead of re-deriving it from screen code alone.
- Whenever you change navigation structure, input/output formats, or the logic behind any
  documented algorithm/flowchart, update `docs/system_design.md` in the same change — including
  redrawing the affected Mermaid flowchart so it still matches the code. Treat this as part of the
  task, not a follow-up.
- If a change is purely cosmetic (styling, spacing, copy) and doesn't alter behavior, inputs,
  outputs, or logic branches, no doc update is needed.

## 8. Testing Discipline

**`docs/testing.md` defines the test types and methodology this project uses; `docs/system_design.md`,
`docs/data_flow_diagram.md`, and `docs/data_dictionary.md` are the source material test cases must be derived from.**

- Before writing or running any test, read `docs/testing.md` to pick the applicable test type(s),
  and read the relevant sections of `docs/system_design.md` / `docs/data_flow_diagram.md` / `docs/data_dictionary.md` for the
  behavior, flow, or data being tested — don't invent test cases from assumptions.
- Every testing session (new-feature testing or regression testing) must have a written test plan.
  Copy `docs/test-plans/TEMPLATE.md` to `docs/test-plans/YYYY-MM-DD-topic.md`, fill it in before
  testing, and record actual results after. Do not run ad-hoc tests without a corresponding test
  plan file.

## 9. Established Patterns

**Before writing a helper, check whether one already exists.** A 2026-08 refactor collapsed
dozens of near-duplicates into these; re-implementing them undoes that work.

| Need | Use | Where |
|---|---|---|
| Delete confirmation dialog | `confirmDelete(context, s)` | `widgets/confirm_dialog.dart` |
| Open a bottom sheet | `showAppSheet()` wrapping a `SheetBody` | `widgets/sheet_body.dart` |
| Cap a single-column screen on desktop | `ResponsiveBody` | `widgets/responsive_body.dart` |
| Drag-reorder drop zones and ordering | `dropZoneFor()`, `orderBetween()` | `widgets/drag_reorder.dart` |
| A new list-shaped provider | extend `SyncedListNotifier<T>` | `providers/synced_list_notifier.dart` |
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

### Hard rules

1. **Never run `dart format`.** It reformats whole files and buries the real change.
   Hand-edit indentation, and only on lines you already touched.
2. **Never write `catchError((_) {})` or `catch (_) {}` around a write.** Route failures through
   `reportSyncError(ref, e)` so the UI can surface them. A parse fallback is the one exception,
   and it needs a comment saying so.
3. **Declare sheet state outside the `showAppSheet` `builder:`.** Flutter re-runs that builder on
   any MediaQuery change (the keyboard alone does it), so state declared inside is silently reset
   — the symptom is "tapping does nothing, I have to press it several times".
4. **l10n changes touch four files.** `l10n/app_strings.dart` plus the three implementations.
   Verify with `grep -c "@override" src/lib/l10n/strings_*.dart` — all three must match.
   Full-width punctuation (`？` `：` `（）`) belongs inside the localized string, never
   concatenated at the call site.
5. **No bare `fontSize:`.** Use a `Theme.of(context).textTheme.*` role. If no role matches the
   size, keep it inline and add one English comment saying why.
6. **Check subclass overrides before touching `SyncedListNotifier`.** e.g. `JournalNotifier`
   overrides `mergeToUser` to filter out `auto_`-prefixed auto-filled entries; the generic base
   does not.
7. **Only top-level semester goals carry `future_goal_id`.** Enforced in
   `linkFutureGoal()` and cleared by `reparent()`; see `system_design.md` UC4.
8. **Widget tests run in guest mode, and guest mode never reaches Supabase.**
   Three traps are documented in `docs/testing.md` §2.6 — the tab pages own no
   `Scaffold`, `IndexedStack` hides the unselected ones from the default finder,
   and `pumpApp()` reloads every provider from SharedPreferences, so seed data
   *after* the pump. Assert UI text through `StringsZhTw()` and friends, never
   as a literal. No golden tests.
9. **Text length caps live in two places that must agree.** `InputLimits`
   (`src/lib/core/input_limits.dart`) caps what can be typed; the columns that
   reach Supabase carry the same cap as a `CHECK (char_length(col) <= N)` in
   `supabase/input_length_limits.sql`, which the user runs by hand. Change a
   number in one and change it in the other, and add both when a new free-text
   field appears — a cap only in the app lets old builds write over-long rows,
   and one only in the database shows up as a sync failure (`23514`) after the
   user has typed. `SheetTextField`'s `maxLength` is required for this reason.
   See `docs/data_dictionary.md` D0.
10. **Every screen is responsive and animated by the rules below** — §10 Responsive Design,
    §11 Motion and §12 Styles are part of "done", not polish for later.

## 10. Responsive Design

**Always concern responsive designs.** The same build runs on a 360-px phone, a tablet and a
1400-px desktop window; a screen is finished only when it works at all three.

- **Layout follows the window width, never the platform.** A narrow web window gets the
  phone layout. Breakpoints live in `AppBreakpoints`: below `desktop` (768) is the phone
  layout with a bottom navigation bar; from 768 the navigation rail; from `wide` (1200) the
  extended rail and larger content caps.
- **Cap line length on wide screens.** Single-column screens go inside `ResponsiveBody`;
  bottom sheets are capped at 640 by the theme; pages keep `AppSpacing.pageHorizontal`
  (20) at the sides.
- **No horizontal scroll, no overflow stripes.** A `Text` inside a `Row` gets `Flexible`
  or `Expanded` plus `maxLines`/`overflow`; long user titles wrap rather than being cut
  (see §2-K in `system_design.md`). Never size a list with `IntrinsicHeight` — lay the row
  out and paint decorations over it with a `Stack`.
- **Floating things are placed against the screen, not hard-coded.** Tour cards use
  `placeCoachCard()` (beside the target on wide screens, above/below on phones, clear of
  the keyboard); add buttons are draggable and remember their position as a fraction.
- **Check three widths**: 360, 768 and 1280. Widget tests set the size with
  `setViewWidth()`; a layout rule that matters gets a test at more than one width.

## 11. Motion

`system_design.md` §3-Q is the source of truth. Movement follows Material 3 motion: it
explains where something came from and where it went, and never makes the user wait.

- **Durations and curves come only from `AppMotion`** — never a bare millisecond number.
  `enter` (emphasized decelerate) for things arriving, `exit` (emphasized accelerate,
  shorter) for things leaving, `move` (standard) for things already on screen changing
  place or value, `page` for page-level transitions, `hold` for the pause after a tick.
- **Pick the transition by the relationship:** top-level tabs fade in (no slide — they are
  not a sequence); ordinary pages use the platform transition from the theme (predictive
  back on Android, Cupertino on Apple, fade-forwards elsewhere); a card opening its own
  detail grows into it (`ExpandingCard`); steps of a flow use shared axis; sheets rise.
- **Respect "reduce motion".** Custom controllers and holds are multiplied by
  `motionScale(context)`; implicit animations take `scaled(context, …)`, which returns one
  microsecond rather than zero (`AnimatedSize` asserts on a zero duration).
- **Lists change through `AnimatedRows`**: a removed row can be held, then folds away; new
  rows unfold. Counts in headings use `FlipText`.
- **Animate with controllers, never `Timer` or `Future.delayed`.** `pumpAndSettle()` waits
  for controllers and fails on stray timers; a ticked task stays on screen for about 0.55 s,
  so tests settle before asserting it has gone (`testing.md` §2.6).
- **Vibration only through `haptic()`**, which obeys the user's own switch (D25). Buzz for a
  tick, the day's last task and a drop — nothing else.

## 12. Styles

The user picks one of several styles (colours, typeface and corner radius together —
`system_design.md` §3-R). The app switches style at run time, so:

- **Colours come only from `AppColors`, radii only from `AppRadius`.** No `Color(0x…)` in
  screens. Category and avatar colours are the user's data and deliberately the same in
  every style.
- **An expression that reads `AppColors` or `AppRadius` cannot be `const`** — they are
  getters over the current style.
- **Look at a new screen in a light style and in Midnight (dark).** Anything drawn on a
  hard-coded white or black is suspect.
- **A new style must pass `test/app_styles_test.dart`** (WCAG contrast for body, secondary
  and on-primary text) before it ships.
- **The Android side is generated.** Launcher icons, splash themes and the widget's colours
  come from `scripts/style_assets/generate.py` reading `palettes.json`. Change a palette in
  `kStylePalettes` and you change `palettes.json` and re-run the script in the same change —
  `test/style_assets_test.dart` fails otherwise. Never hard-code a colour in the widget's
  Kotlin or layouts; go through `WidgetStyle`.
- **A new style is also a launcher alias** (`AndroidManifest.xml`), a `LaunchTheme.<Style>`
  and an entry in `MainActivity`'s and `WidgetStyle`'s lists — the assets test checks all four.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.