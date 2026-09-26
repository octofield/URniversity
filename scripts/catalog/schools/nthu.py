# -*- coding: utf-8 -*-
"""National Tsing Hua University, from its official open data: one JSON file
with every course of the current semester, published for exactly this kind of
reuse. One request a run. Older semesters are not in it, so only the current
one can be fetched.

A record, as the file writes it (2026-09):
  "科號": "11510AES 450100"          year 115, term 10 (20 spring, 30 summer)
  "教室與上課時間": "BMES醫環618\tW2W3W4\n"   a line per room: room, tab, codes
  "授課教師": "李清福\tLEE, CHING-FU\n"      a line per teacher
  "必選修說明": "分環所115M  選修\t…"          an entry per audience
Weekdays are M T W R F S U; periods 1–4, n, 5–9, a–d (schools.json).
"""
import html
import json
import re

import common

CODE = 'nthu'
URL = 'https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/JH/OPENDATA/open_course_data.json'

PERIODS = common.load_periods(CODE)
_WEEKDAYS = {'M': 1, 'T': 2, 'W': 3, 'R': 4, 'F': 5, 'S': 6, 'U': 7}
_CODE = re.compile(r'([MTWRFSU])([1-9nabcd])')
# The summer term (30) is left out: the app has no summer semester
_TERMS = {'10': '1', '20': '2'}

_cache = {}


def load():
    """The whole file, fetched once however many times it is asked for."""
    if 'data' not in _cache:
        _cache['data'] = json.loads(common.fetch_text(URL))
    return _cache['data']


def semester_of(course_no):
    """"11510AES 450100" -> "115-1"; None for summer or anything unexpected."""
    m = re.match(r'(\d{3})(\d{2})', course_no or '')
    if not m or m.group(2) not in _TERMS:
        return None
    return '%s-%s' % (m.group(1), _TERMS[m.group(2)])


def default_semesters():
    return sorted({s for s in (semester_of(r['科號']) for r in load()) if s})


def _lines(text):
    return [line.split('\t') for line in (text or '').split('\n') if line.strip()]


def parse_time(text):
    """"LS II生二 113\tT2T3T4\nLS II生二220\tTnT5\n" -> one session per room and
    weekday run, the room as its location."""
    out = []
    for parts in _lines(text):
        room = ' '.join(parts[0].split()) if len(parts) > 1 else ''
        by_day = {}
        for day, label in _CODE.findall(parts[-1]):
            by_day.setdefault(_WEEKDAYS[day], []).append(label)
        for weekday, labels in by_day.items():
            out += common.periods_to_sessions(weekday, labels, PERIODS, room)
    return sorted(out, key=lambda s: (s['weekday'], s['start_minute']))


def to_record(item):
    course_no = item['科號']
    code = ' '.join(course_no[5:].split())
    entries = [e.split() for e in (item.get('必選修說明') or '').split('\t') if e.strip()]
    audiences = []
    for e in entries:
        # "分環所115M" -> "分環所": the year and degree say nothing to a student
        name = re.sub(r'\d{3}[A-Z]$', '', e[0])
        if name not in audiences:
            audiences.append(name)
    try:
        credits = float(item.get('學分數') or '')
    except ValueError:
        credits = None
    return {
        'key': code,
        'course_code': code,
        'class_no': None,
        'serial_no': None,
        'title': html.unescape(item.get('課程中文名稱') or '').strip(),
        'teacher': '、'.join(html.unescape(p[0]).strip() for p in _lines(item.get('授課教師')) if p[0].strip()),
        'credits': credits,
        'required': entries[0][-1] if entries and len(entries[0]) > 1 else None,
        'audience': audiences,
        'time_text': '；'.join(' '.join(' '.join(p).split()) for p in _lines(item.get('教室與上課時間'))),
        'sessions': parse_time(item.get('教室與上課時間')),
    }


def fetch(semester):
    data = load()
    here = [r for r in data if semester_of(r.get('科號')) == semester]
    if not here:
        present = ', '.join(default_semesters()) or 'none'
        return common.Fetched([], 0, False, 'the open data only has %s' % present)
    # Cancelled courses stay in the file with a note; nobody can take them
    records = [to_record(r) for r in here if not (r.get('停開註記') or '').strip()]
    records = [r for r in records if r['title']]
    cancelled = len(here) - len(records)
    note = '%d cancelled or untitled, left out' % cancelled if cancelled else ''
    # The file is one document: parsed whole, it is complete
    return common.Fetched(records, len(here) - cancelled, len(records) > 0, note)
