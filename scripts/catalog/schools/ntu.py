# -*- coding: utf-8 -*-
"""National Taiwan University, from NOL, its older public course search
(nol.ntu.edu.tw). It needs no login and no JavaScript; NTU publishes no course
API, and the newer course.ntu.edu.tw bans scripted requests outright — never
point this at it. Any semester NOL still lists; by default this one and the
last.

Why "all departments, paged" rather than one query per department — learned
the hard way on NOL:
  1. dptname filters on the result's audience column; a course with no
     audience belongs to no department and a per-department loop never sees it
  2. page_cnt tops out at 150 rows whatever is asked for, so without paging
     anything past row 150 of a department silently disappears
  3. a course is listed once per audience, so per-department queries fetch it
     many times over
dptname=0 with a startrec offset covers everything in about 110 requests.
"""
import re
import time
import urllib.error
import urllib.parse

from bs4 import BeautifulSoup

import common

CODE = 'ntu'
BASE_URL = 'https://nol.ntu.edu.tw/nol/coursesearch/search_for_02_dpt.php'
DELAY_S = 0.35            # between pages: this is someone else's server
ROWS_PER_PAGE = 150       # NOL's hard cap per page, and the startrec step
MAX_PAGES = 400           # a safety stop if the page ever stops paging
RETRY_ROUNDS = 3
RETRY_DELAY_S = 2.0

# The result table's 18 columns, as measured on NOL:
#   0 serial  1 audience  2 course code  3 class  4 title  5 field  6 credits
#   7 course id  8 full/half year  9 required  10 teacher  11 add method
#   12 time and room  13 size  14 restrictions  15 notes  16 web  17 planned
COL_SERIAL, COL_AUDIENCE, COL_CODE, COL_CLASS, COL_TITLE = 0, 1, 2, 3, 4
COL_CREDITS, COL_REQUIRED, COL_TEACHER, COL_TIME = 6, 9, 10, 12

PERIODS = common.load_periods(CODE)
_WEEKDAYS = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7}
# "三6,7 (基醫508)": a weekday, its periods, then the room if there is one.
# Period 10 is the one label longer than a character
_LABEL = r'(?:10|[0-9A-D])'
_SEGMENT = re.compile(r'([一二三四五六日])\s*(%s(?:\s*,\s*%s)*)\s*(?:\(([^)]*)\))?' % (_LABEL, _LABEL))


def parse_time(text):
    """NOL's time-and-room column: "三6,7 (基醫508)", "一3,4(新102)四8(普101)",
    "五A,B". Anything it cannot read — "請洽系所辦", an empty cell — yields no
    sessions rather than a guess."""
    out = []
    for m in _SEGMENT.finditer(text or ''):
        labels = [label.strip() for label in m.group(2).split(',')]
        location = (m.group(3) or '').strip()
        out += common.periods_to_sessions(_WEEKDAYS[m.group(1)], labels, PERIODS, location)
    return out


def page_url(semester, startrec):
    return '%s?%s' % (BASE_URL, urllib.parse.urlencode({
        'current_sem': semester, 'dptname': '0', 'page_cnt': ROWS_PER_PAGE, 'startrec': startrec,
    }))


def previous_semester(sem):
    """115-2 -> 115-1, 115-1 -> 114-2. NOL has no summer codes."""
    year, half = sem.split('-')
    return '%s-1' % year if half == '2' else '%d-2' % (int(year) - 1)


def current_semester(html):
    m = re.search(r'name="current_sem"[^>]*value="([^"]+)"', html) or \
        re.search(r'value="([^"]+)"[^>]*name="current_sem"', html)
    if not m:
        raise RuntimeError('no current_sem on the search page; has NOL changed?')
    return m.group(1)


def default_semesters():
    current = current_semester(common.fetch_text(BASE_URL))
    return [current, previous_semester(current)]


def total_count(html):
    """NOL's own "共查詢到 N 筆" — the completeness check compares against it."""
    text = re.sub(r'\s+', '', BeautifulSoup(html, 'html.parser').get_text())
    m = re.search(r'共查詢到(\d+)筆', text)
    return int(m.group(1)) if m else None


def parse_rows(html):
    """Every course row on one result page, one dict per row (audiences repeat)."""
    soup = BeautifulSoup(html, 'html.parser')
    header = soup.find('tr', attrs={'bgcolor': '#DDEDFF'})
    if header is None:
        return []
    rows = []
    for tr in header.find_parent('table').find_all('tr')[1:]:
        cells = tr.find_all('td')
        if len(cells) <= COL_TIME:
            continue
        text = [c.get_text(' ', strip=True) for c in cells]
        title_cell = cells[COL_TITLE]
        title = (title_cell.find('a').get_text(strip=True) if title_cell.find('a') else text[COL_TITLE])
        if not text[COL_CODE] or not title:
            continue
        try:
            credits = float(text[COL_CREDITS])
        except ValueError:
            credits = None
        rows.append({
            'serial_no': text[COL_SERIAL],
            'audience': text[COL_AUDIENCE],
            'course_code': text[COL_CODE],
            'class_no': text[COL_CLASS],
            'title': title,
            'credits': credits,
            'required': text[COL_REQUIRED],
            'teacher': text[COL_TEACHER],
            'time_text': re.sub(r'\s+', ' ', text[COL_TIME]).strip(),
        })
    return rows


def to_record(row):
    """A NOL row in the shared record shape. The serial number is the key; the
    few courses without one fall back to code, class and teacher."""
    key = row['serial_no'] or '%s_%s_%s' % (row['course_code'], row['class_no'], row['teacher'])
    return dict(row, key=key, audience=[row['audience']], sessions=parse_time(row['time_text']))


def fetch(semester):
    first = common.fetch_text(page_url(semester, 0))
    total = total_count(first)
    if total is None:
        raise RuntimeError('no "共查詢到 N 筆"; has NOL changed?')
    rows = parse_rows(first)
    failed = []
    page, startrec = 1, ROWS_PER_PAGE
    while startrec < total and page < MAX_PAGES:
        time.sleep(DELAY_S)
        try:
            rows += parse_rows(common.fetch_text(page_url(semester, startrec)))
        except (urllib.error.URLError, OSError) as e:
            failed.append(startrec)
            print('    [%s startrec=%d] failed: %s' % (semester, startrec, e))
        if page % 20 == 0:
            print('    %d/%d rows' % (len(rows), total))
        page, startrec = page + 1, startrec + ROWS_PER_PAGE

    # A hundred-odd requests always meet a stray reset or DNS hiccup; without a
    # retry one bad page throws the whole semester away
    for attempt in range(1, RETRY_ROUNDS + 1):
        if not failed:
            break
        print('    retry round %d: %d pages' % (attempt, len(failed)))
        retrying, failed = failed, []
        for startrec in retrying:
            time.sleep(RETRY_DELAY_S)
            try:
                rows += parse_rows(common.fetch_text(page_url(semester, startrec)))
            except (urllib.error.URLError, OSError) as e:
                failed.append(startrec)
                print('      startrec=%d still failing: %s' % (startrec, e))

    note = '%d pages failed' % len(failed) if failed else ''
    return common.Fetched([to_record(r) for r in rows], total, not failed and len(rows) == total, note)
