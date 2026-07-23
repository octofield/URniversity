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

**`docs/DFD.md` (Data Flow Diagram) and `docs/DD.md` (Data Dictionary) are the source of truth for persisted data.**

- Before reading or reasoning about how data is stored, loaded, or flows between the app and
  Supabase / SharedPreferences, consult `docs/DFD.md` and `docs/DD.md` first instead of
  re-deriving it from provider code alone.
- Whenever you change persisted data — adding/removing/renaming a Supabase table column, a
  SharedPreferences key, a model field, or the read/write flow of a Provider in
  `src/lib/providers/` — update `docs/DFD.md` and `docs/DD.md` in the same change so they stay
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
`docs/DFD.md`, and `docs/DD.md` are the source material test cases must be derived from.**

- Before writing or running any test, read `docs/testing.md` to pick the applicable test type(s),
  and read the relevant sections of `docs/system_design.md` / `docs/DFD.md` / `docs/DD.md` for the
  behavior, flow, or data being tested — don't invent test cases from assumptions.
- Every testing session (new-feature testing or regression testing) must have a written test plan.
  Copy `docs/test-plans/TEMPLATE.md` to `docs/test-plans/YYYY-MM-DD-topic.md`, fill it in before
  testing, and record actual results after. Do not run ad-hoc tests without a corresponding test
  plan file.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.