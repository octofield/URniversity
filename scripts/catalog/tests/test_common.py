# -*- coding: utf-8 -*-
"""What every school shares. Run: python -m pytest scripts/catalog"""
import common

NTU = common.load_periods('ntu')
STAMP = '2026-09-26T00:00:00+00:00'


def hm(h, m):
    return h * 60 + m


def record(key, **kw):
    r = {'key': key, 'title': 'Course', 'audience': []}
    r.update(kw)
    return r


def test_consecutive_periods_are_one_session_and_a_gap_splits_them():
    assert common.periods_to_sessions(1, ['2', '3', '5'], NTU, '新102') == [
        common.session(1, hm(9, 10), hm(11, 10), '新102'),
        common.session(1, hm(12, 20), hm(13, 10), '新102'),
    ]


def test_order_follows_the_table_not_the_text():
    assert common.periods_to_sessions(2, ['4', '3'], NTU) == [common.session(2, hm(10, 20), hm(12, 10))]


def test_a_label_the_table_lacks_is_dropped_not_guessed():
    assert common.periods_to_sessions(3, ['X'], NTU) == []
    assert common.periods_to_sessions(3, ['X', '6'], NTU) == [common.session(3, hm(13, 20), hm(14, 10))]


def test_ids_carry_the_school_and_the_semester():
    rows = common.finish('nthu', '115-1', [record('AES 450100')], STAMP)
    assert rows[0]['id'] == 'nthu_115-1_AES 450100'
    assert rows[0]['school'] == 'nthu'
    assert rows[0]['updated_at'] == STAMP


def test_one_key_is_one_row_with_every_audience():
    rows = common.finish('ntu', '115-1', [
        record('1', audience=['A'], teacher='first'),
        record('1', audience=['B', 'A'], teacher='second'),
    ], STAMP)
    assert len(rows) == 1
    assert rows[0]['audience'] == 'A、B'
    assert rows[0]['teacher'] == 'first'


def test_text_is_cut_to_the_database_caps_and_sessions_to_twenty():
    rows = common.finish('ntu', '115-1', [
        record('1', title='課' * 150, teacher='', sessions=[common.session(1, i, i + 1) for i in range(30)]),
    ], STAMP)
    assert len(rows[0]['title']) == 100
    assert rows[0]['teacher'] is None
    assert len(rows[0]['sessions']) == 20


def test_semester_codes():
    assert common.is_semester('115-1')
    assert common.is_semester('115-2')
    assert not common.is_semester('115-3')
    assert not common.is_semester('1151')


def test_every_school_has_a_module_and_a_period_table():
    from schools import REGISTRY
    schools = common.load_schools()
    assert set(REGISTRY) == set(schools)
    for code in schools:
        periods = common.load_periods(code)
        assert periods, code
        # Periods run forwards and never overlap
        for (_, _, end), (_, start, _) in zip(periods, periods[1:]):
            assert end < start, code


def test_required_for_is_merged_across_a_keys_records():
    rows = common.finish('ntu', '115-1', [
        record('1', audience=['A'], required_for=['A']),
        record('1', audience=['B'], required_for=[]),
        record('1', audience=['C'], required_for=['C', 'A']),
    ], STAMP)
    assert rows[0]['required_for'] == ['A', 'C']
    assert rows[0]['kind'] is None


def test_a_class_start_without_its_month_takes_the_first_that_fits():
    import datetime
    # 7 on a Monday in Aug–Oct 2026: only September
    assert common.class_start('115-1', 7, common.WEEKDAY_CHARS['一']) == datetime.date(2026, 9, 7)
    # 15 on a Monday in Jan–Mar 2027: February and March both are; the earlier
    assert common.class_start('115-2', 15, common.WEEKDAY_CHARS['一']) == datetime.date(2027, 2, 15)
    # No weekday to go by: the window's first month
    assert common.class_start('115-1', 31) == datetime.date(2026, 8, 31)
    assert common.class_start('115-1', 7, common.WEEKDAY_CHARS['日']) is None


def test_the_maintainers_dates_are_the_fallback():
    assert common.term_defaults('nthu')['115-1'] == {'first_day': '2026-09-07', 'weeks': 16}


def test_the_calendar_first_then_schools_json_then_nothing():
    import datetime
    import types
    import fetch_catalog

    def calendar(year):
        return {'115-1': datetime.date(2026, 9, 8)} if year == 115 else {}

    found = types.SimpleNamespace(fetch_term_starts=calendar)
    starts, report = fetch_catalog.term_starts(found, 'nthu', ['115-1', '115-2', '99-1'])
    # The calendar wins over schools.json's 2026-09-07; 115-2 is only in
    # schools.json; 99-1 is in neither and is left out
    assert starts == {'115-1': {'first_day': '2026-09-08', 'weeks': 16},
                      '115-2': {'first_day': '2027-02-15', 'weeks': 16}}
    assert [r[2] for r in report] == ['calendar', 'schools.json', 'none']

    def unreadable(year):
        raise ValueError('no such link')

    broken = types.SimpleNamespace(fetch_term_starts=unreadable)
    starts, report = fetch_catalog.term_starts(broken, 'nthu', ['115-1'])
    assert starts['115-1']['first_day'] == '2026-09-07'
    assert report[0][2] == 'schools.json'


def test_recording_a_school_keeps_the_terms_written_before():
    sent = []

    def fake_rest(env, method, path, body=None, prefer=None):
        if method == 'GET':
            return [{'semesters': ['114-2'], 'audiences': [],
                     'term_starts': {'114-2': {'first_day': '2026-02-23', 'weeks': 16}}}]
        sent.append(body)
        return None

    real = common._rest
    common._rest = fake_rest
    try:
        common.record_school({}, 'ntu', ['115-1'], (), {'115-1': {'first_day': '2026-09-07', 'weeks': 16}})
    finally:
        common._rest = real
    assert sent[0][0]['term_starts'] == {
        '114-2': {'first_day': '2026-02-23', 'weeks': 16},
        '115-1': {'first_day': '2026-09-07', 'weeks': 16},
    }
    assert sent[0][0]['semesters'] == ['114-2', '115-1']
