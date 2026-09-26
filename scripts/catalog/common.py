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
          'required': 10, 'audience': 200, 'time_text': 100}
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
            merged[key] = dict(r, audiences=[])
        for a in r.get('audience') or []:
            if a and a not in merged[key]['audiences']:
                merged[key]['audiences'].append(a)
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


def record_school(env, code, semesters):
    """catalog_schools: the app's list of schools it can search, and for which
    semesters. Semesters written before are kept."""
    info = load_schools()[code]
    existing = _rest(env, 'GET', 'catalog_schools?' + urllib.parse.urlencode({
        'code': 'eq.' + code, 'select': 'semesters',
    })) or []
    known = set(existing[0]['semesters'] or []) if existing else set()
    _rest(env, 'POST', 'catalog_schools', [{
        'code': code,
        'name': info['name'],
        'short_name': info['short_name'],
        'semesters': sorted(known | set(semesters)),
        'updated_at': now_stamp(),
    }], prefer='resolution=merge-duplicates,return=minimal')
