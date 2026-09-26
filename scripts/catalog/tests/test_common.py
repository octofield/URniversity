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
