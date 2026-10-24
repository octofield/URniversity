"""Checks supabase/friends.sql with two real accounts (test plan M1).

What a friend may read is decided on the server, so it is checked there: each
step below signs in as one of the two accounts and calls Supabase directly,
the way anyone holding that account's session could, and prints PASS or FAIL.
Nothing here is inferred from the app.

Use two throwaway accounts (email and password sign-in), not real ones: the
script sends requests between them, switches account A's timetable sharing on
and off, and unfriends them at the end. Each account's share switches are put
back as they were.

    set SUPABASE_URL=https://<project>.supabase.co
    set SUPABASE_ANON_KEY=<the anon key the app uses; public, not the service key>
    set A_EMAIL=...   set A_PASSWORD=...
    set B_EMAIL=...   set B_PASSWORD=...
    set FRIENDS_CHECK_SEMESTER=115-1      (optional; give account A a course in it)
    python scripts/friends_check/check.py

Standard library only. Exits 1 if any check fails.
"""

import json
import os
import sys
import urllib.error
import urllib.request

URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
KEY = os.environ.get('SUPABASE_ANON_KEY', '')
SEMESTER = os.environ.get('FRIENDS_CHECK_SEMESTER', '115-1')

failures = []


def check(name, ok, detail=''):
    print(('PASS  ' if ok else 'FAIL  ') + name + (f'  ({detail})' if detail and not ok else ''))
    if not ok:
        failures.append(name)


def call(method, path, token=None, body=None, prefer=None):
    """Returns (status, parsed body or None). HTTP errors are answers here."""
    headers = {'apikey': KEY, 'Content-Type': 'application/json'}
    headers['Authorization'] = f'Bearer {token or KEY}'
    if prefer:
        headers['Prefer'] = prefer
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as res:
            text = res.read().decode()
            return res.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        try:
            return e.code, json.loads(text)
        except ValueError:
            return e.code, text


class Account:
    def __init__(self, label, email, password):
        status, body = call('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': password})
        if status != 200:
            sys.exit(f'Could not sign in as {label}: {status} {body}')
        self.label = label
        self.token = body['access_token']
        self.id = body['user']['id']

    def rpc(self, fn, **params):
        return call('POST', f'/rest/v1/rpc/{fn}', self.token, params)

    def select(self, table, query):
        return call('GET', f'/rest/v1/{table}?{query}', self.token)

    def shares(self):
        _, rows = self.select('user_settings', f'select=share_graph,share_rates,share_timetable&user_id=eq.{self.id}')
        return rows[0] if rows else {'share_graph': False, 'share_rates': False, 'share_timetable': False}

    def set_shares(self, **values):
        return call('POST', '/rest/v1/user_settings?on_conflict=user_id', self.token,
                    {'user_id': self.id, **values}, prefer='resolution=merge-duplicates')

    def friendships(self):
        _, rows = self.select('friendships', 'select=*')
        return rows if isinstance(rows, list) else []


def error_code(body):
    return body.get('message') if isinstance(body, dict) else None


def main():
    missing = [k for k in ('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'A_EMAIL', 'A_PASSWORD', 'B_EMAIL', 'B_PASSWORD')
               if not os.environ.get(k)]
    if missing:
        sys.exit('Set ' + ', '.join(missing) + ' (see the top of this file)')

    a = Account('A', os.environ['A_EMAIL'], os.environ['A_PASSWORD'])
    b = Account('B', os.environ['B_EMAIL'], os.environ['B_PASSWORD'])
    a_shares, b_shares = a.shares(), b.shares()

    # A clean start: no row between them, A sharing nothing
    for row in a.friendships():
        if b.id in (row['requester_id'], row['addressee_id']):
            call('DELETE', f"/rest/v1/friendships?id=eq.{row['id']}", a.token)
    a.set_shares(share_graph=False, share_rates=False, share_timetable=False)

    try:
        print('— Before they are friends')
        status, body = b.rpc('friend_timetable', friend=a.id, semester=SEMESTER)
        check('friend_timetable gives nothing', status == 200 and body is None, f'{status} {body}')
        for table in ('courses', 'tasks', 'semester_goals', 'future_goals', 'user_settings'):
            status, rows = b.select(table, f'select=*&user_id=eq.{a.id}')
            check(f'B reads none of A\'s {table} directly', status == 200 and rows == [], f'{status} {rows}')

        print('— Asking')
        status, code = a.rpc('my_friend_code')
        check('A gets an invite code', status == 200 and isinstance(code, str) and len(code) == 8, f'{status} {code}')
        status, body = b.rpc('friend_code_owner', code=code.lower())
        check('B sees whose code it is', status == 200 and len(body) == 1 and body[0]['user_id'] == a.id, f'{status} {body}')
        status, body = b.rpc('request_friend', code=code)
        check('B sends a request; it waits', status == 200 and body == 'pending', f'{status} {body}')
        status, body = b.rpc('request_friend', code=code)
        check('asking twice: already', error_code(body) == 'already', f'{status} {body}')
        _, b_code = b.rpc('my_friend_code')
        status, body = b.rpc('request_friend', code=b_code)
        check('asking oneself: self', error_code(body) == 'self', f'{status} {body}')
        status, body = b.rpc('request_friend', code='ZZZZZZZZ' if code != 'ZZZZZZZZ' else 'YYYYYYYY')
        check('an unknown code: not_found', error_code(body) == 'not_found', f'{status} {body}')

        row = next((r for r in b.friendships() if r['addressee_id'] == a.id), None)
        check('the request is one pending row', row is not None and row['status'] == 'pending', str(row))
        status, body = b.rpc('respond_friend', friendship=row['id'], accept=True)
        check('B cannot accept its own request', error_code(body) == 'not_allowed', f'{status} {body}')

        print('— Writing around the functions')
        status, body = call('POST', '/rest/v1/friendships', b.token,
                            {'requester_id': a.id, 'addressee_id': b.id, 'status': 'accepted'})
        check('a direct insert is refused', status >= 400, f'{status} {body}')
        call('PATCH', f"/rest/v1/friendships?id=eq.{row['id']}", b.token, {'status': 'accepted'})
        after = next((r for r in b.friendships() if r['id'] == row['id']), None)
        check('a direct update changes nothing', after is not None and after['status'] == 'pending', str(after))
        status, body = b.rpc('friend_timetable', friend=a.id, semester=SEMESTER)
        check('still nothing while pending', body is None, f'{status} {body}')

        print('— Friends')
        status, body = a.rpc('friend_list')
        incoming = [r for r in body if r['user_id'] == b.id] if isinstance(body, list) else []
        check('A sees B\'s request', len(incoming) == 1 and incoming[0]['status'] == 'incoming', f'{status} {body}')
        status, body = a.rpc('respond_friend', friendship=row['id'], accept=True)
        check('A accepts', status in (200, 204), f'{status} {body}')

        status, body = b.rpc('friend_timetable', friend=a.id, semester=SEMESTER)
        check('A shares nothing: B reads nothing', body is None, f'{status} {body}')
        a.set_shares(share_timetable=True)
        status, body = b.rpc('friend_list')
        mine = [r for r in body if r['user_id'] == a.id] if isinstance(body, list) else []
        check('B sees that A shares the timetable', mine and mine[0]['share_timetable'] is True and mine[0]['share_rates'] is False,
              f'{status} {body}')
        status, body = b.rpc('friend_timetable', friend=a.id, semester=SEMESTER)
        check('A shares the timetable: B reads it', isinstance(body, dict) and 'courses' in body, f'{status} {body}')
        courses = body.get('courses', []) if isinstance(body, dict) else []
        if not courses:
            print(f'      (A has no course in {SEMESTER}: add one to check what a course carries)')
        leaked = {k for c in courses for k in c} - {'id', 'title', 'color', 'sessions'}
        leaked |= {k for c in courses for s in c.get('sessions', []) for k in s} - {'weekday', 'start_minute', 'end_minute'}
        check('no grade, credits, teacher or room in it', not leaked, ', '.join(sorted(leaked)))
        status, rows = b.select('courses', f'select=*&user_id=eq.{a.id}')
        check('the courses table itself still says no', rows == [], f'{status} {rows}')

        print('— Rates and the graph (7-2)')
        status, body = b.rpc('friend_rates', friend=a.id)
        check('rates not shared: nothing', status == 200 and body is None, f'{status} {body}')
        status, body = b.rpc('friend_graph', friend=a.id)
        check('graph not shared: nothing', status == 200 and body is None, f'{status} {body}')
        a.set_shares(share_rates=True, share_graph=True)
        status, rates = b.rpc('friend_rates', friend=a.id)
        check("rates shared: B reads A's tasks", status == 200 and isinstance(rates, list), f'{status} {rates}')
        rates = rates if isinstance(rates, list) else []
        if not rates:
            print('      (A has no tasks: add one to check what a task carries)')
        check('every title is empty', all(r.get('title') == '' for r in rates))
        leaked = {k for r in rates for k in r} - {'id', 'title', 'due_time', 'is_completed', 'completed_dates', 'created_at',
                                                 'recurrence_type', 'recurrence_interval', 'recurrence_weekdays',
                                                 'recurrence_month_days'}
        check('no content, links or anything else about a task', not leaked, ', '.join(sorted(leaked)))
        status, graph = b.rpc('friend_graph', friend=a.id)
        check('graph shared: B reads it', status == 200 and isinstance(graph, dict), f'{status} {graph}')
        graph = graph if isinstance(graph, dict) else {}
        goals = graph.get('futures', []) + graph.get('semesters', [])
        check('no notes on any vision or target', all('notes' not in g for g in goals))
        _, milestones = a.select('semester_goals', f'select=id&user_id=eq.{a.id}&parent_id=not.is.null')
        milestone_ids = {m['id'] for m in milestones} if isinstance(milestones, list) else set()
        check('targets only, no milestones', not milestone_ids & {g['id'] for g in graph.get('semesters', [])})
        check('task counts are numbers, not tasks',
              all(isinstance(v, int) for v in (graph.get('counts') or {}).values()), str(graph.get('counts')))

        print('— Unfriending')
        status, body = call('DELETE', f"/rest/v1/friendships?id=eq.{row['id']}", a.token)
        check('A removes B', status in (200, 204), f'{status} {body}')
        status, body = b.rpc('friend_timetable', friend=a.id, semester=SEMESTER)
        check('B reads nothing at once', body is None, f'{status} {body}')
        _, body = b.rpc('friend_rates', friend=a.id)
        check('nor the rates', body is None, str(body))
        _, body = b.rpc('friend_graph', friend=a.id)
        check('nor the graph', body is None, str(body))
    finally:
        a.set_shares(**a_shares)
        b.set_shares(**b_shares)

    print()
    if failures:
        print(f'{len(failures)} failed')
        sys.exit(1)
    print('All passed')


if __name__ == '__main__':
    main()
