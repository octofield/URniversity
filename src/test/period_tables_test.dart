import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/period_tables.dart';

// Each school's period table lives twice: scripts/catalog/schools.json turns a
// catalog's periods into times, period_tables.dart labels the grid and the
// manual picker. A course found in the catalog must land on the same periods
// the app draws, so changing one without the other fails here
void main() {
  final json = jsonDecode(File('../scripts/catalog/schools.json').readAsStringSync()) as Map<String, dynamic>;
  String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  test('every school with a Dart table is in schools.json under the same name', () {
    final names = {for (final school in json.values) (school as Map<String, dynamic>)['name'] as String};
    expect(names, containsAll(kSchoolPeriods.keys));
  });

  test('the periods match, label by label', () {
    for (final school in json.values.cast<Map<String, dynamic>>()) {
      final dart = kSchoolPeriods[school['name']];
      // A school may have a catalog before the app has its table
      if (dart == null) continue;
      expect(
        [for (final p in dart) [p.label, hm(p.start), hm(p.end)]],
        school['periods'],
        reason: school['name'] as String,
      );
    }
  });
}
