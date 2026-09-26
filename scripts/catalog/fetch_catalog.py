# -*- coding: utf-8 -*-
"""Fetches schools' course catalogs into Supabase (course_catalog, and the list
of searchable schools in catalog_schools). One script for every school: pick
the schools and, if you like, the semesters.

Run by hand once a semester, from the repository root:

    python scripts/catalog/fetch_catalog.py --list
    python scripts/catalog/fetch_catalog.py --school=ntu --semesters=115-1
    python scripts/catalog/fetch_catalog.py --school=ntu,nthu          (each school's defaults)
    python scripts/catalog/fetch_catalog.py --school=all --dry-run     (fetch and parse, write nothing)
    python scripts/catalog/fetch_catalog.py --school=ntu --allow-partial   (escape hatch)

Needs scripts/catalog/.env with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
(the service role key bypasses RLS and must never leave this machine; .env is
git-ignored). See README.md.
"""
import sys

import common
from schools import REGISTRY


def option(argv, name):
    arg = next((a for a in argv if a.startswith('--%s=' % name)), None)
    return [v.strip() for v in arg.split('=', 1)[1].split(',') if v.strip()] if arg else None


def list_schools():
    info = common.load_schools()
    for code, module in REGISTRY.items():
        doc = (module.__doc__ or '').strip().splitlines()[0]
        print('  %-6s %s（%s）  %s' % (code, info[code]['name'], info[code]['short_name'], doc))


def main(argv):
    if '--list' in argv:
        list_schools()
        return 0

    codes = option(argv, 'school')
    if not codes:
        print('Pick the schools: --school=ntu, --school=ntu,nthu or --school=all. Known:')
        list_schools()
        return 1
    if codes == ['all']:
        codes = list(REGISTRY)
    unknown = [c for c in codes if c not in REGISTRY]
    if unknown:
        print('Unknown school: %s. Known: %s' % (', '.join(unknown), ', '.join(REGISTRY)))
        return 1

    semesters = option(argv, 'semesters')
    bad = [s for s in semesters or [] if not common.is_semester(s)]
    if bad:
        print('Semesters look like 115-1 or 115-2, not %s' % ', '.join(bad))
        return 1

    dry_run = '--dry-run' in argv
    allow_partial = '--allow-partial' in argv
    env = common.load_env()
    if not dry_run and not (env.get('SUPABASE_URL') and env.get('SUPABASE_SERVICE_ROLE_KEY')):
        print('Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY in scripts/catalog/.env')
        return 1

    failed_any = False
    report = []
    for code in codes:
        module = REGISTRY[code]
        try:
            wanted = semesters or module.default_semesters()
        except Exception as e:  # noqa: BLE001 - one school failing must not stop the others
            print('%s: could not tell which semesters: %s' % (code, e))
            failed_any = True
            continue
        print('%s: %s' % (code, ', '.join(wanted)))
        written = []
        for semester in wanted:
            print('  %s ...' % semester)
            try:
                fetched = module.fetch(semester)
            except Exception as e:  # noqa: BLE001 - one semester failing must not stop the others
                print('  %s failed: %s' % (semester, e))
                failed_any = True
                continue
            stamp = common.now_stamp()
            rows = common.finish(code, semester, fetched.records, stamp)
            # A time the module could not read: the course would land nowhere
            # on the grid, so it is counted rather than passed over
            unread = [r['time_text'] for r in rows if r['time_text'] and not r['sessions']]
            if unread:
                print('  unread times, e.g.: %s' % ' | '.join(sorted(set(unread))[:8]))
            report.append((code, semester, fetched.source_count, len(fetched.records), len(rows), len(unread),
                           fetched.complete, fetched.note))
            # Incomplete means courses someone may be looking for are missing.
            # Better to keep last run's rows than write half
            if not fetched.complete and not allow_partial:
                print('  %s incomplete; not written. %s' % (semester, fetched.note))
                failed_any = True
                continue
            if dry_run:
                continue
            # A partial write never prunes: a missing page is not a cancelled course
            common.write_semester(env, code, semester, rows, stamp, prune=fetched.complete)
            written.append(semester)
            print('  %s written: %d courses' % (semester, len(rows)))
        if written:
            common.record_school(env, code, written)

    print('\nschool  semester   source     parsed     courses    unread times')
    for code, semester, source, parsed, courses, unread, complete, note in report:
        flag = '' if complete else '   ⚠ incomplete'
        print('  %-6s%-11s%-11d%-11d%-11d%d%s%s' % (code, semester, source, parsed, courses, unread, flag,
                                                   ('   ' + note) if note else ''))
    return 1 if failed_any else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
