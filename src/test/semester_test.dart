import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/utils/semester_helpers.dart';

void main() {
  const twoSem = SemesterSettings(count: 2, startMonths: [8, 2]);
  const threeSem = SemesterSettings(count: 3, startMonths: [8, 12, 4]);
  const fourSem = SemesterSettings(count: 4, startMonths: [8, 11, 2, 5]);
  final s = StringsEn();

  group('generateSemesters', () {
    test('interleaves each semester with the break that follows it', () {
      final sems = generateSemesters(twoSem);
      // A 2-semester year yields 1, B1, 2, B2 per academic year
      final firstYear = sems.take(4).map((x) => x.split('-')[1]).toList();
      expect(firstYear, ['1', 'B1', '2', 'B2']);
    });

    test('produces twice as many entries as semesters per year', () {
      for (final settings in [twoSem, threeSem, fourSem]) {
        final sems = generateSemesters(settings);
        expect(sems.length % (settings.count * 2), 0,
            reason: 'count=${settings.count}');
      }
    });

    test('every token parses as year-semester or year-break', () {
      for (final token in generateSemesters(threeSem)) {
        final parts = token.split('-');
        expect(parts.length, 2);
        expect(int.tryParse(parts[0]), isNotNull);
        final tail = parts[1];
        expect(tail.startsWith('B') ? int.tryParse(tail.substring(1)) : int.tryParse(tail),
            isNotNull);
      }
    });
  });

  group('compareSemesters', () {
    test('orders a break after its own semester but before the next', () {
      expect(compareSemesters('114-1', '114-B1'), lessThan(0));
      expect(compareSemesters('114-B1', '114-2'), lessThan(0));
    });

    test('orders by year first', () {
      expect(compareSemesters('114-B2', '115-1'), lessThan(0));
    });

    test('is reflexive and antisymmetric', () {
      expect(compareSemesters('114-1', '114-1'), 0);
      expect(compareSemesters('114-2', '114-1'), greaterThan(0));
    });

    test('sorts a generated list into the order it was generated', () {
      final sems = generateSemesters(fourSem);
      final shuffled = [...sems]..shuffle();
      shuffled.sort(compareSemesters);
      expect(shuffled, sems);
    });
  });

  group('breakName', () {
    test('the break after the last semester is always summer', () {
      expect(breakName(2, 2, s), s.summerBreak);
      expect(breakName(3, 3, s), s.summerBreak);
      expect(breakName(4, 4, s), s.summerBreak);
    });

    test('two-semester years name the mid-year break winter', () {
      expect(breakName(1, 2, s), s.winterBreak);
    });

    test('three-semester years are winter then spring', () {
      expect(breakName(1, 3, s), s.winterBreak);
      expect(breakName(2, 3, s), s.springBreak);
    });

    test('four-semester years are autumn, winter, spring', () {
      expect(breakName(1, 4, s), s.autumnBreak);
      expect(breakName(2, 4, s), s.winterBreak);
      expect(breakName(3, 4, s), s.springBreak);
    });
  });

  group('formatSemester', () {
    test('leaves a normal semester token untouched', () {
      expect(formatSemester('114-1', twoSem, s), '114-1');
    });

    test('renders a break token with its localized name', () {
      expect(formatSemester('114-B1', twoSem, s), '114 ${s.winterBreak}');
      expect(formatSemester('114-B2', twoSem, s), '114 ${s.summerBreak}');
    });

    test('the same token renames when the semester count changes', () {
      // Documented limitation: break names are positional, not stored
      expect(formatSemester('114-B1', twoSem, s), '114 ${s.winterBreak}');
      expect(formatSemester('114-B1', fourSem, s), '114 ${s.autumnBreak}');
    });
  });

  group('currentSemester', () {
    test('returns a plain semester token, never a break', () {
      final token = currentSemester(twoSem);
      expect(token.split('-')[1].startsWith('B'), isFalse);
    });

    test('is a member of the generated list', () {
      expect(generateSemesters(twoSem), contains(currentSemester(twoSem)));
    });
  });
}
