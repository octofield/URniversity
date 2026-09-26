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
