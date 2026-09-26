# -*- coding: utf-8 -*-
"""NTHU: seven real records from its open data (fixtures/nthu), trimmed from
the 2026-09 file, plus the cases the file happened not to have."""
import io
import json
import os

import common
from schools import nthu

FIXTURE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       'fixtures', 'nthu', 'open_course_data.json')
STAMP = '2026-09-26T00:00:00+00:00'


def hm(h, m):
    return h * 60 + m


def data():
    return json.load(io.open(FIXTURE, encoding='utf-8'))


def by_code(course_no):
    return next(nthu.to_record(r) for r in data() if r['科號'] == course_no)


def use(records):
    # Stands in for the one request the module would make
    nthu._cache['data'] = records


def test_the_semester_is_in_the_course_number():
    assert nthu.semester_of('11510AES 450100') == '115-1'
    assert nthu.semester_of('11520AES 450100') == '115-2'
    assert nthu.semester_of('11530AES 450100') is None  # summer
    assert nthu.semester_of('') is None


def test_one_room_three_periods_is_one_session():
    r = by_code('11510AES 450100')
    assert r['key'] == 'AES 450100'
    assert r['course_code'] == 'AES 450100'
    assert r['serial_no'] is None
    assert r['title'] == '環境微生物學'
    assert r['credits'] == 3.0
    assert r['teacher'] == '李清福'
    assert r['sessions'] == [common.session(3, hm(9, 0), hm(12, 0), 'BMES醫環618')]
    assert r['time_text'] == 'BMES醫環618 W2W3W4'


def test_every_teacher_and_every_audience():
    r = by_code('11510AES 470200')
    assert r['teacher'] == '陳俊銘、周秀專'
    assert r['sessions'] == [common.session(4, hm(13, 20), hm(16, 20), 'EDU教 103')]
    many = by_code('11510ANTH651000')
    assert many['audience'] == ['人類所', '台研教在職學位班']
    assert many['required'] == '選修'


def test_two_rooms_and_the_noon_period():
    r = by_code('11510BAI 500700')
    assert r['sessions'] == [
        common.session(2, hm(9, 0), hm(12, 0), 'LS II生二 113'),
        common.session(2, hm(12, 10), hm(14, 10), 'LS II生二220'),
    ]


def test_a_run_into_the_evening_stays_one_session():
    assert by_code('11510AIA 500500')['sessions'] == [common.session(2, hm(15, 30), hm(19, 20), 'DELTA台達105')]


def test_no_time_no_sessions_and_entities_are_decoded():
    assert by_code('11510AES 510100')['sessions'] == []
    assert by_code('11510AES 510100')['time_text'] == ''
    # &#28201; is U+6E29
    assert by_code('11510AIA 200200')['teacher'] == 'NYCU温、洪仕軒'
    assert by_code('11510AIA 200200')['required'] is None


def test_a_gap_and_two_days_split():
    assert nthu.parse_time('R 101\tM3M4M6F3\n') == [
        common.session(1, hm(10, 10), hm(12, 0), 'R 101'),
        common.session(1, hm(14, 20), hm(15, 10), 'R 101'),
        common.session(5, hm(10, 10), hm(11, 0), 'R 101'),
    ]


def test_fetch_keeps_the_semester_and_leaves_out_cancelled_courses():
    records = data()
    cancelled = dict(records[0], **{'科號': '11510ZZZ 000100', '停開註記': '停開'})
    summer = dict(records[0], **{'科號': '11530ZZZ 000200'})
    use(records + [cancelled, summer])
    fetched = nthu.fetch('115-1')
    assert fetched.complete
    assert len(fetched.records) == len(records)
    assert fetched.source_count == len(records)
    assert 'ZZZ 000100' not in [r['key'] for r in fetched.records]
    assert nthu.default_semesters() == ['115-1']


def test_a_semester_the_file_does_not_have_is_incomplete_and_says_why():
    use(data())
    fetched = nthu.fetch('114-2')
    assert not fetched.complete
    assert fetched.records == []
    assert '115-1' in fetched.note


def test_rows_for_the_database():
    use(data())
    rows = common.finish('nthu', '115-1', nthu.fetch('115-1').records, STAMP)
    assert len(rows) == 7
    assert rows[0]['id'] == 'nthu_115-1_AES 450100'
    assert all(len(r['teacher'] or '') <= common.LIMITS['teacher'] for r in rows)
