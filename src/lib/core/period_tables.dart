// Class periods by school (system_design.md §3-S), each as its registrar
// publishes it. A school without a table simply uses clock times everywhere.
// scripts/catalog/schools.json holds the same tables for reading each school's
// catalog; test/period_tables_test.dart keeps the two in step.

class ClassPeriod {
  // As the school writes it: NTU 0–10 then A–D, NTHU 1–4, n, 5–9 then a–d
  final String label;
  // Minutes since midnight
  final int start;
  final int end;

  const ClassPeriod(this.label, this.start, this.end);
}

int _hm(int h, int m) => h * 60 + m;

const kNtuSchool = '國立臺灣大學';

final kNtuPeriods = <ClassPeriod>[
  ClassPeriod('0', _hm(7, 10), _hm(8, 0)),
  ClassPeriod('1', _hm(8, 10), _hm(9, 0)),
  ClassPeriod('2', _hm(9, 10), _hm(10, 0)),
  ClassPeriod('3', _hm(10, 20), _hm(11, 10)),
  ClassPeriod('4', _hm(11, 20), _hm(12, 10)),
  ClassPeriod('5', _hm(12, 20), _hm(13, 10)),
  ClassPeriod('6', _hm(13, 20), _hm(14, 10)),
  ClassPeriod('7', _hm(14, 20), _hm(15, 10)),
  ClassPeriod('8', _hm(15, 30), _hm(16, 20)),
  ClassPeriod('9', _hm(16, 30), _hm(17, 20)),
  ClassPeriod('10', _hm(17, 30), _hm(18, 20)),
  ClassPeriod('A', _hm(18, 25), _hm(19, 15)),
  ClassPeriod('B', _hm(19, 20), _hm(20, 10)),
  ClassPeriod('C', _hm(20, 15), _hm(21, 5)),
  ClassPeriod('D', _hm(21, 10), _hm(22, 0)),
];

const kNthuSchool = '國立清華大學';

final kNthuPeriods = <ClassPeriod>[
  ClassPeriod('1', _hm(8, 0), _hm(8, 50)),
  ClassPeriod('2', _hm(9, 0), _hm(9, 50)),
  ClassPeriod('3', _hm(10, 10), _hm(11, 0)),
  ClassPeriod('4', _hm(11, 10), _hm(12, 0)),
  ClassPeriod('n', _hm(12, 10), _hm(13, 0)),
  ClassPeriod('5', _hm(13, 20), _hm(14, 10)),
  ClassPeriod('6', _hm(14, 20), _hm(15, 10)),
  ClassPeriod('7', _hm(15, 30), _hm(16, 20)),
  ClassPeriod('8', _hm(16, 30), _hm(17, 20)),
  ClassPeriod('9', _hm(17, 30), _hm(18, 20)),
  ClassPeriod('a', _hm(18, 30), _hm(19, 20)),
  ClassPeriod('b', _hm(19, 30), _hm(20, 20)),
  ClassPeriod('c', _hm(20, 30), _hm(21, 20)),
  ClassPeriod('d', _hm(21, 30), _hm(22, 20)),
];

// Keyed by the school name the profile stores (taiwan_universities.dart)
final kSchoolPeriods = <String, List<ClassPeriod>>{
  kNtuSchool: kNtuPeriods,
  kNthuSchool: kNthuPeriods,
};

// The periods of the user's school, or null when it has no table
List<ClassPeriod>? periodsFor(String? school) => kSchoolPeriods[school];

// The period a session starts in, for labelling it ("3–4"), when it lines up
String? periodRangeLabel(List<ClassPeriod>? periods, int start, int end) {
  if (periods == null) return null;
  final first = periods.where((p) => p.start == start).firstOrNull;
  final last = periods.where((p) => p.end == end).firstOrNull;
  if (first == null || last == null) return null;
  return first == last ? first.label : '${first.label}–${last.label}';
}
