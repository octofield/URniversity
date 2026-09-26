# Course catalogs

`fetch_catalog.py` fills Supabase's `course_catalog` table (docs/data_dictionary.md
D29) with schools' courses, and `catalog_schools` (D32) with which schools and
semesters can be searched. It's one script for every school, so the timetable's
"Search NTU courses" / "Search NTHU courses" can add a course in one tap.

Run it **by hand, once a semester**, when a school opens course selection.

| Code | School | Source | Semesters |
|---|---|---|---|
| `ntu` | 國立臺灣大學 | NOL public course search, about 110 pages, 0.35 s apart | Any NOL still lists; by default this one and the last |
| `nthu` | 國立清華大學 | Official open data, one JSON file | Only the current one |

## First time

1. Run `supabase/course_catalog.sql` in the Supabase SQL Editor.
2. `pip install -r scripts/catalog/requirements.txt`
3. Copy `.env.example` to `.env` in this folder, and fill in the project URL
   and the **service role** key (Supabase → Project Settings → API).
   - The key bypasses RLS: keep it on this machine only. `.env` is git-ignored.
   - This folder used to be `scripts/ntu_catalog/`. A `.env` made there moves
     here.

## Every semester

```
python scripts/catalog/fetch_catalog.py --list                         # the schools
python scripts/catalog/fetch_catalog.py --school=ntu --semesters=115-1
python scripts/catalog/fetch_catalog.py --school=ntu,nthu              # each school's own defaults
python scripts/catalog/fetch_catalog.py --school=all --dry-run         # fetch and parse, write nothing
```

`--school` is required, so a run never reaches a server nobody asked for.

The table at the end has these columns:

| Column | Meaning |
|---|---|
| `source` | What the school says it has |
| `parsed` | What was read |
| `courses` | Records after merging |
| `unread times` | Courses with a time the script couldn't turn into sessions |

`unread times` should stay near zero, and the run prints a few examples.
On 115-1, none of them had a fixed class time:
- NTU: 13 courses list only teaching weeks ("第1,2,3 週").
- NTHU: 2 courses list a room and no time at all.

- An incomplete semester is **not written**, so last run's rows stay as they are.
  - Run again to fill the gap.
  - `--allow-partial` writes what was read, but should not be needed.
- A complete run updates rows in place (upsert on `id`).
- A complete run then removes that semester's courses it no longer saw: the ones
  the school has cancelled.

Measured on 115-1 (2026-09-26):
- NTU: NOL listed 16,032 rows, all parsed, merged into 12,044 courses.
- NTHU: 3,043 courses.

## Being a polite client

- **Never point anything at `course.ntu.edu.tw`.** It answers scripted requests
  with "You got banned permanently from this server". NOL needs no login or
  JavaScript.
- Keep each school's delay. Don't run it more often than it needs.

## Adding a school

1. **Check the school allows it.** Look for open data, or a public query page
   that needs no login, and read its robots.txt and terms. Prefer open data.
2. **`schools.json`:** add the code, the name exactly as the app's school list
   writes it (`src/lib/core/taiwan_universities.dart`), a short name, and the
   period table from the registrar.
3. **`schools/<code>.py`:** give it `CODE`, `default_semesters()` and
   `fetch(semester)`. The contract is at the top of `schools/__init__.py`.
   - Read times with `common.periods_to_sessions`, so the app needs nothing new.
   - Register the module in `REGISTRY`.
4. **Tests:** save a few real records or pages under `fixtures/<code>/` and
   write `tests/test_<code>.py`.
5. **Run it:** `--school=<code> --dry-run`, check the table, then run without
   `--dry-run`.
   - The school appears in the app's "Add course" at once. No new build needed.
6. **Optional, in the app:**
   - Add the period table to `src/lib/core/period_tables.dart` (`kSchoolPeriods`).
   - Students there can then pick periods when adding by hand, and the grid
     shows period labels.
   - `test/period_tables_test.dart` checks it against `schools.json`.

## What is stored

- **One record per course.** NTU lists a course once per audience, so the
  audiences are merged into `audience`.
- **`time_text`** is kept as the school writes it, for display.
- **`sessions`** are the meetings read from that text. They have the same shape
  as a course's own sessions, and are copied there when a course is added.

## Tests

```
python -m pytest scripts/catalog
```

`fixtures/ntu/` holds two real NOL pages, trimmed to the result table.
`fixtures/nthu/` holds seven real records from the 2026-09 open data file.
