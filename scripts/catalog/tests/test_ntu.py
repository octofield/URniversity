# -*- coding: utf-8 -*-
"""NTU: the parser on saved NOL pages (fixtures/ntu), and the time column."""
import io
import os

import common
from schools import ntu

FIXTURES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'fixtures', 'ntu')
STAMP = '2026-09-26T00:00:00+00:00'


def fixture(name):
    return io.open(os.path.join(FIXTURES, name), encoding='utf-8').read()


def hm(h, m):
    return h * 60 + m


def rows_of(name, semester='115-1'):
    return common.finish('ntu', semester, [ntu.to_record(r) for r in ntu.parse_rows(fixture(name))], STAMP)


def test_reads_every_row_and_the_total():
    html = fixture('nol_page.html')
    assert len(ntu.parse_rows(html)) == 15
    assert ntu.total_count(html) == 16032


def test_columns_land_in_the_right_fields():
    row = ntu.parse_rows(fixture('nol_page.html'))[0]
    assert row['serial_no'] == '45247'
    assert row['course_code'] == 'Genom7019'
    assert row['title'] == '生物標記物與它們的產地'
    assert row['credits'] == 2.0
    assert row['required'] == '選修'
    assert row['teacher'] == '許書睿'
    assert row['time_text'] == '三6,7 (基醫508)'


def test_the_time_column_becomes_sessions_in_the_row():
    first = rows_of('nol_page.html')[0]
    assert first['sessions'] == [common.session(3, hm(13, 20), hm(15, 10), '基醫508')]


def test_one_course_listed_for_many_audiences_is_one_record():
    by_serial = {r['serial_no']: r for r in rows_of('nol_page.html')}
    assert len(by_serial) == 4
    genomics = by_serial['39490']
    assert genomics['id'] == 'ntu_115-1_39490'
    assert genomics['audience'].split('、') == ['基因學位學程', '分子醫學學程', '智慧醫療學程', '基蛋所', '生化分生所']


def test_courses_without_a_serial_number_still_get_a_stable_id():
    rows = rows_of('nol_page_no_serial.html')
    assert len(rows) == 1
    assert rows[0]['id'] == 'ntu_115-1_Common1011__'
    assert rows[0]['time_text'] is None
    assert rows[0]['sessions'] == []


def test_semesters_step_back_across_the_year():
    assert ntu.previous_semester('115-2') == '115-1'
    assert ntu.previous_semester('115-1') == '114-2'


# The cases the app's parseNtuTime was tested on, before reading times moved here

def test_one_meeting_with_a_room_with_or_without_a_space():
    assert ntu.parse_time('三6,7 (基醫508)') == [common.session(3, hm(13, 20), hm(15, 10), '基醫508')]
    assert ntu.parse_time('二6,7(基醫1303)') == [common.session(2, hm(13, 20), hm(15, 10), '基醫1303')]


def test_two_days_each_with_its_own_room():
    assert ntu.parse_time('一3,4(新102)四8(普101)') == [
        common.session(1, hm(10, 20), hm(12, 10), '新102'),
        common.session(4, hm(15, 30), hm(16, 20), '普101'),
    ]


def test_evening_letters_and_period_ten():
    assert ntu.parse_time('五A,B') == [common.session(5, hm(18, 25), hm(20, 10))]
    assert ntu.parse_time('四9,10') == [common.session(4, hm(16, 30), hm(18, 20))]
    # Period 10 on its own, not period 1 followed by a stray 0
    assert ntu.parse_time('四10') == [common.session(4, hm(17, 30), hm(18, 20))]


def test_a_gap_makes_two_sessions():
    assert ntu.parse_time('一2,3,5') == [
        common.session(1, hm(9, 10), hm(11, 10)),
        common.session(1, hm(12, 20), hm(13, 10)),
    ]


def test_what_it_cannot_read_gives_nothing():
    assert ntu.parse_time('') == []
    assert ntu.parse_time('請洽系所辦') == []


# Credits by category (system_design.md §3-T)

def test_required_for_collects_the_audiences_it_is_compulsory_for():
    rows = rows_of('nol_page_no_serial.html')
    assert rows[0]['required_for'][:2] == ['生技系', '生科系']
    elective = {r['serial_no']: r for r in rows_of('nol_page.html')}['40428']
    assert elective['required_for'] == []


def test_common_courses_count_as_general_education():
    assert rows_of('nol_page_no_serial.html')[0]['kind'] == common.KIND_GENERAL
    assert {r['serial_no']: r for r in rows_of('nol_page.html')}['40428']['kind'] is None


def test_the_general_education_page_gives_serials_and_its_total():
    html = fixture('gen_ed_page.html')
    serials = {r['serial_no'] for r in ntu.parse_rows(html)}
    assert '49992' in serials
    assert ntu.total_count(html) == 324
    row = {'serial_no': '49992', 'course_code': 'CHIN1096'}
    assert ntu.kind_of(row, serials) == common.KIND_GENERAL
    assert ntu.kind_of({'serial_no': '1', 'course_code': 'PE1012'}, serials) == common.KIND_EXCLUDED


def test_a_departments_credits_to_graduate():
    # CSIE, entry year 114: required 51, general 24, elective 53, total 128
    assert ntu.parse_requirement_totals(fixture('requirements_9020_114.html')) == (51, 24, 53, 128)
    assert ntu.parse_requirement_totals('<html><body>No data</body></html>') is None


def test_a_department_with_a_group_reads_by_its_full_code():
    # Medicine, fetched as dpt=40100 (the form's value) rather than 4010
    assert ntu.parse_requirement_totals(fixture('requirements_40100_114.html')) == (201, 24, 0, 225)


# First day of classes (2026-10-03)

def test_the_calendar_sheet_gives_both_terms_first_days():
    import datetime
    import openpyxl
    sheet = openpyxl.load_workbook(os.path.join(FIXTURES, 'calendar_115.xlsx'), data_only=True).worksheets[0]
    rows = [tuple(c.value for c in row) for row in sheet.iter_rows()]
    assert ntu.class_starts_from_rows(rows) == {
        '115-1': datetime.date(2026, 9, 7),
        '115-2': datetime.date(2027, 2, 22),
    }
