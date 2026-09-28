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
import json
import re
import time
import urllib.error
import urllib.parse

from bs4 import BeautifulSoup

import common

CODE = 'ntu'
BASE_URL = 'https://nol.ntu.edu.tw/nol/coursesearch/search_for_02_dpt.php'
# General education is listed on a page of its own, by area: the main list
# gives such a course only its home department's code (CHIN1096)
GEN_ED_URL = 'https://nol.ntu.edu.tw/nol/coursesearch/search_for_03_co.php'
# a: all areas; 1–8: A1–A8; b: communication and careers, up to 6 credits of
# which count as general education. e (freshman seminars) does not count
GEN_ED_AREAS = ('a', '1', '2', '3', '4', '5', '6', '7', '8', 'b')
# Each department's credits to graduate by entry year, as JSON and one HTML
# page per department (curri.aca.ntu.edu.tw, the registrar's own query)
REQUIREMENTS_API = 'https://curri.aca.ntu.edu.tw/NTUVoxCourse/index.php/api/'
REQUIREMENTS_PAGE = 'https://curri.aca.ntu.edu.tw/NTUVoxCourse/uquery/search-result'
# Entry years kept: this year's intake and six before it, which covers
# students taking longer than four years
ENTRY_YEARS = 7
DELAY_S = 0.35            # between pages: this is someone else's server
ROWS_PER_PAGE = 150       # NOL's hard cap per page, and the startrec step
MAX_PAGES = 400           # a safety stop if the page ever stops paging
RETRY_ROUNDS = 3
RETRY_DELAY_S = 2.0
REQUIREMENTS_DELAY_S = 0.5  # another office's server, a few hundred pages

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


def kind_of(row, gen_ed_serials):
    """general: a general education course, or a common one (College Chinese,
    Freshman English: course codes "Common…"). excluded: physical education,
    whose credits the registrar does not count toward graduation."""
    code = row['course_code'] or ''
    if code.startswith('Common') or (row['serial_no'] and row['serial_no'] in gen_ed_serials):
        return common.KIND_GENERAL
    if code.startswith('PE'):
        return common.KIND_EXCLUDED
    return None


def to_record(row, gen_ed_serials=frozenset()):
    """A NOL row in the shared record shape. The serial number is the key; the
    few courses without one fall back to code, class and teacher. NOL lists a
    course once per audience, each with its own 必/選修, so a row adds its
    audience to required_for when the course is compulsory for it."""
    key = row['serial_no'] or '%s_%s_%s' % (row['course_code'], row['class_no'], row['teacher'])
    return dict(row, key=key, audience=[row['audience']], sessions=parse_time(row['time_text']),
                required_for=[row['audience']] if row['required'] == '必修' else [],
                kind=kind_of(row, gen_ed_serials))


def gen_ed_url(semester, area, startrec):
    return '%s?%s' % (GEN_ED_URL, urllib.parse.urlencode({
        'current_sem': semester, 'classarea': area, 'op': 'stu', 'page_cnt': ROWS_PER_PAGE, 'startrec': startrec,
    }))


def fetch_gen_ed_serials(semester):
    """Serial numbers of the semester's general education courses, every
    area, every page. Raises if a page cannot be had: a course left out would
    be filed as an elective without anyone noticing."""
    serials = set()
    for area in GEN_ED_AREAS:
        startrec, total = 0, None
        while total is None or startrec < total:
            time.sleep(DELAY_S)
            html = common.fetch_text(gen_ed_url(semester, area, startrec))
            total = total_count(html) or 0
            serials |= {r['serial_no'] for r in parse_rows(html) if r['serial_no']}
            startrec += ROWS_PER_PAGE
    return serials


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

    try:
        gen_ed = fetch_gen_ed_serials(semester)
    except (urllib.error.URLError, OSError) as e:
        return common.Fetched([to_record(r) for r in rows], total, False, 'general education list failed: %s' % e)
    note = '%d pages failed' % len(failed) if failed else '%d general education' % len(gen_ed)
    return common.Fetched([to_record(r, gen_ed) for r in rows], total, not failed and len(rows) == total, note)


# Credits to graduate --------------------------------------------------------

def parse_requirement_totals(html):
    """(required, general, elective, total) from a department's page: the
    "Total" row under the per-semester table, then "Minimum credits for
    graduation". Found by shape, not by label, so the language does not
    matter. None when the page has no such table."""
    table = BeautifulSoup(html, 'html.parser').find('table', class_='totcrd-top-table')
    if table is None:
        return None
    numbers = []
    for tr in table.find_all('tr'):
        if not tr.find('td', class_='highlight-td'):
            continue
        values = [td.get_text(strip=True) for td in tr.find_all('td') if 'highlight-td' not in (td.get('class') or [])]
        numbers.append([int(v) for v in values if v.isdigit()])
    if len(numbers) < 2 or len(numbers[0]) != 3 or len(numbers[1]) != 1:
        return None
    required, general, elective = numbers[0]
    return required, general, elective, numbers[1][0]


def fetch_requirements():
    """Every bachelor's department's credits to graduate, for the latest
    ENTRY_YEARS entry years. -> (rows, failed): rows for degree_requirements,
    and the (year, department) pages that could not be read."""
    years = json.loads(common.fetch_text(REQUIREMENTS_API + 'semesters'))['data'][:ENTRY_YEARS]
    rows, failed = [], []
    for year in years:
        time.sleep(REQUIREMENTS_DELAY_S)
        depts = json.loads(common.fetch_text(REQUIREMENTS_API + 'departments?' + urllib.parse.urlencode({
            'year': year, 'lang': 'zh'})))['data']
        for dept in depts:
            # 'value' is what the query form submits: the department with its
            # group ("40100" for Medicine). 'data' drops the group and finds
            # nothing for the departments that have one
            code, name = dept['value'].strip(), dept['text'].strip()
            time.sleep(REQUIREMENTS_DELAY_S)
            try:
                totals = parse_requirement_totals(common.fetch_text('%s?%s' % (
                    REQUIREMENTS_PAGE, urllib.parse.urlencode({'semester': year, 'dpt': code, 'lang': 'zh'}))))
            except (urllib.error.URLError, OSError):
                totals = None
            if totals is None:
                failed.append((year, name))
                continue
            required, general, elective, total = totals
            rows.append({'school': CODE, 'entry_year': int(year), 'department': name[:50], 'required': required,
                         'general': general, 'elective': elective, 'total': total})
        print('    %s: %d departments' % (year, len(depts)))
    return rows, failed
