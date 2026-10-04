# -*- coding: utf-8 -*-
"""What every school shares: polite fetching, the period tables, turning
periods into sessions, the database row, and writing to Supabase.

A school module (schools/<code>.py) only knows its own source; everything a
row must satisfy in the database lives here, once."""
import collections
import datetime
import io
import json
import os
import ssl
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
USER_AGENT = 'URniversity-catalog/1.0 (once-a-semester course list for a student planner)'
TIMEOUT_S = 30
UPSERT_BATCH = 500

# Matches supabase/course_catalog.sql: text is cut, never rejected
LIMITS = {'title': 100, 'teacher': 50, 'course_code': 20, 'serial_no': 20, 'class_no': 10,
          'required': 10, 'audience': 200, 'time_text': 100, 'audience_name': 50}

# A course's place in the credits to graduate, when the school's data says so
# (system_design.md §3-T): general education (with the common Chinese and
# English), or not counted at all (physical education). None: the student's
# department decides between required and elective
KIND_GENERAL = 'general'
KIND_EXCLUDED = 'excluded'
ID_MAX = 80
MAX_SESSIONS = 20

# What a school module hands back for one semester. `source_count` is how many
# rows the source itself says it has, `complete` whether every one was read
Fetched = collections.namedtuple('Fetched', 'records source_count complete note')


# Some schools' certificates have no Subject Key Identifier, which Python
# 3.13's strict X.509 mode rejects. Only that one flag is dropped: the chain
# and the host name are still verified
_TLS = ssl.create_default_context()
_TLS.verify_flags &= ~getattr(ssl, 'VERIFY_X509_STRICT', 0)


def fetch_bytes(url, timeout=TIMEOUT_S):
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout, context=_TLS) as res:
        return res.read()


def fetch_text(url, timeout=TIMEOUT_S):
    raw = fetch_bytes(url, timeout)
    try:
        return raw.decode('utf-8-sig')
    except UnicodeDecodeError:
        return raw.decode('cp950', errors='replace')


def load_schools():
    """schools.json: each school's name, short name and period table. The app's
    period_tables.dart must agree; test/period_tables_test.dart checks it."""
    return json.load(io.open(os.path.join(HERE, 'schools.json'), encoding='utf-8'))


def _minutes(hm):
    h, m = hm.split(':')
    return int(h) * 60 + int(m)


def load_periods(code):
    """[(label, start minute, end minute)] in the school's own order."""
    return [(label, _minutes(start), _minutes(end)) for label, start, end in load_schools()[code]['periods']]


def session(weekday, start, end, location=None):
    """One meeting, in the shape of the app's CourseSession JSON."""
    return {'weekday': weekday, 'start_minute': start, 'end_minute': end, 'location': location or None}


def periods_to_sessions(weekday, labels, periods, location=None):
    """Consecutive periods become one session; "2,3,5" is 2–3 and 5. Order
    follows the table, so NTHU's 9 then a is still one run. A label the table
    does not have is dropped rather than guessed."""
    order = [p[0] for p in periods]
    idx = sorted({order.index(label) for label in labels if label in order})
    out = []
    run = 0
    for k in range(1, len(idx) + 1):
        if k == len(idx) or idx[k] != idx[k - 1] + 1:
            out.append(session(weekday, periods[idx[run]][1], periods[idx[k - 1]][2], location))
            run = k
    return out


# Python's weekday() for the weekday characters calendars print
WEEKDAY_CHARS = {'一': 0, '二': 1, '三': 2, '四': 3, '五': 4, '六': 5, '日': 6}


def class_start(semester, day, weekday=None):
    """The date a semester's classes start on, from a calendar that gives the
    day of the month (and perhaps the weekday) but not always the month: the
    earliest month in the term's usual window (Aug–Oct, Jan–Mar) where that
    day exists and falls on that weekday. None if none does."""
    roc, half = semester.split('-')
    year = int(roc) + 1911 + (1 if half == '2' else 0)
    for month in ((8, 9, 10) if half == '1' else (1, 2, 3)):
        try:
            d = datetime.date(year, month, day)
        except ValueError:
            continue
        if weekday is None or d.weekday() == weekday:
            return d
    return None


def term_defaults(code):
    """The maintainer's first days of classes in schools.json, for when a
    school's calendar cannot be read: {semester: {first_day, weeks}}."""
    info = load_schools()[code]
    weeks = info.get('term_weeks', 16)
    return {s: {'first_day': d, 'weeks': weeks} for s, d in info.get('term_starts', {}).items()}


def is_semester(code):
    """The app's own semester code: "115-1", "115-2"."""
    parts = code.split('-')
    return len(parts) == 2 and parts[0].isdigit() and parts[1] in ('1', '2')


def _cut(value, field):
    value = (value or '').strip()
    return value[:LIMITS[field]] if value else None


def finish(school, semester, records, stamp):
    """Database rows from a school's records: one row per key, the id prefixed
    with school and semester, audiences of the same course merged, text cut to
    the caps. The first record of a key supplies everything but the audiences,
    so the result does not depend on the source's order."""
    merged = collections.OrderedDict()
    for r in records:
        key = r['key']
        if key not in merged:
            merged[key] = dict(r, audiences=[], required_by=[])
        for field, into in (('audience', 'audiences'), ('required_for', 'required_by')):
            for a in r.get(field) or []:
                if a and a not in merged[key][into]:
                    merged[key][into].append(a)
    return [
        {
            'id': ('%s_%s_%s' % (school, semester, key))[:ID_MAX],
            'school': school,
            'semester': semester,
            'serial_no': _cut(r.get('serial_no'), 'serial_no'),
            'course_code': _cut(r.get('course_code'), 'course_code'),
            'class_no': _cut(r.get('class_no'), 'class_no'),
            'title': _cut(r['title'], 'title'),
            'teacher': _cut(r.get('teacher'), 'teacher'),
            'credits': r.get('credits'),
            'required': _cut(r.get('required'), 'required'),
            'audience': _cut('、'.join(r['audiences']), 'audience'),
            'time_text': _cut(r.get('time_text'), 'time_text'),
            'sessions': (r.get('sessions') or [])[:MAX_SESSIONS],
            # The audiences it is compulsory for, as the school names them:
            # the app files it as "required" for a student of one of them
            'required_for': [a[:LIMITS['audience_name']] for a in r['required_by']],
            'kind': r.get('kind'),
            'updated_at': stamp,
        }
        for key, r in merged.items()
    ]


def now_stamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


# Supabase ---------------------------------------------------------------------

def load_env():
    path = os.path.join(HERE, '.env')
    env = {}
    if os.path.exists(path):
        for line in io.open(path, encoding='utf-8'):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    env.update({k: v for k, v in os.environ.items() if k.startswith('SUPABASE_')})
    return env


def _rest(env, method, path, body=None, prefer=None):
    key = env['SUPABASE_SERVICE_ROLE_KEY']
    headers = {'apikey': key, 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}
    if prefer:
        headers['Prefer'] = prefer
    data = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None
    req = urllib.request.Request(env['SUPABASE_URL'].rstrip('/') + '/rest/v1/' + path,
                                 data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as res:
        if res.status >= 300:
            raise RuntimeError('%s %s failed: HTTP %d' % (method, path, res.status))
        raw = res.read()
    return json.loads(raw) if raw else None


def write_semester(env, school, semester, rows, stamp, prune=True):
    """Upserts the rows, then — when [prune], i.e. the fetch was complete —
    drops the semester's rows this run did not see: courses the school has
    since cancelled."""
    for i in range(0, len(rows), UPSERT_BATCH):
        # Re-running a semester updates its rows instead of failing on them
        _rest(env, 'POST', 'course_catalog', rows[i:i + UPSERT_BATCH],
              prefer='resolution=merge-duplicates,return=minimal')
    if not prune:
        return
    _rest(env, 'DELETE', 'course_catalog?' + urllib.parse.urlencode({
        'school': 'eq.' + school, 'semester': 'eq.' + semester, 'updated_at': 'lt.' + stamp,
    }), prefer='return=minimal')


def record_school(env, code, semesters, audiences=(), term_starts=None):
    """catalog_schools: the app's list of schools it can search, for which
    semesters, every department name the catalog files required courses under
    (the list a student picks their own from), and each semester's first day
    of classes ({semester: {first_day, weeks}}), the app's default. What was
    written before is kept."""
    info = load_schools()[code]
    existing = _rest(env, 'GET', 'catalog_schools?' + urllib.parse.urlencode({
        'code': 'eq.' + code, 'select': 'semesters,audiences,term_starts',
    })) or []
    old = existing[0] if existing else {}
    _rest(env, 'POST', 'catalog_schools', [{
        'code': code,
        'name': info['name'],
        'short_name': info['short_name'],
        'semesters': sorted(set(old.get('semesters') or []) | set(semesters)),
        'audiences': sorted(set(old.get('audiences') or []) | set(audiences)),
        'term_starts': {**(old.get('term_starts') or {}), **(term_starts or {})},
        'updated_at': now_stamp(),
    }], prefer='resolution=merge-duplicates,return=minimal')


def write_requirements(env, rows):
    """degree_requirements: each department's credits to graduate by entry
    year, replaced whole for the (school, entry year, department) it names."""
    for i in range(0, len(rows), UPSERT_BATCH):
        _rest(env, 'POST', 'degree_requirements?on_conflict=school,entry_year,department',
              rows[i:i + UPSERT_BATCH], prefer='resolution=merge-duplicates,return=minimal')
