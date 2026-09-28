import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/credit_categories.dart';
import 'package:urniversity/core/grade_scale.dart';
import 'package:urniversity/models/course.dart';

// Credits by category (system_design.md §3-T): how an added course is filed,
// what counts toward each category, and the guesses that fill in the settings
void main() {
  group('filing a catalog course', () {
    test('the school\'s own marking comes first', () {
      expect(classifyCourse(kind: 'general', requiredFor: ['資工系'], catalogDepartment: '資工系'), CreditCategory.general);
      expect(classifyCourse(kind: 'excluded'), CreditCategory.excluded);
    });

    test('compulsory for the user\'s department is required, anything else elective', () {
      expect(classifyCourse(requiredFor: ['資工系', '電機系'], catalogDepartment: '資工系'), CreditCategory.required);
      expect(classifyCourse(requiredFor: ['電機系'], catalogDepartment: '資工系'), CreditCategory.elective);
      expect(classifyCourse(requiredFor: ['資工系']), CreditCategory.elective, reason: 'no department chosen yet');
    });
  });

  test('credits per category count passed courses only, at the degree\'s pass mark', () {
    Course course(String category, double credits, String grade) => Course(
          id: '$category$credits$grade', semester: '115-1', title: 'x', credits: credits, grade: grade,
          category: category == 'none' ? null : category, color: 0, createdAt: DateTime(2026),
        );
    final courses = [
      course('required', 3, 'A'),
      course('required', 2, 'F'),
      course('general', 2, 'C-'),
      course('elective', 3, 'pass'),
      course('none', 1, 'B'),
      course('excluded', 1, 'A'),
    ];
    final bachelor = creditsByCategory(courses, DegreeLevel.bachelor);
    expect(bachelor[CreditCategory.required], 3);
    expect(bachelor[CreditCategory.general], 2);
    expect(bachelor[CreditCategory.elective], 3);
    expect(bachelor[null], 1);
    expect(bachelor[CreditCategory.excluded], 1);
    // A graduate student needs a B-: the C- no longer counts
    expect(creditsByCategory(courses, DegreeLevel.graduate)[CreditCategory.general], isNull);
  });

  test('the entry year from the grade given in a year', () {
    expect(entryYearFrom(2, 2026), 114);
    expect(entryYearFrom(1, 2026), 115);
    expect(entryYearFrom(null, 2026), isNull);
  });

  test('the catalog\'s short name for a department is guessed by shared characters', () {
    const names = ['資工系', '資管系', '電機系', '中文系'];
    expect(guessCatalogDepartment('資訊工程學系', names), '資工系');
    expect(guessCatalogDepartment('電機工程學系', names), '電機系');
    expect(guessCatalogDepartment('歷史學系', names), isNull, reason: 'nothing but 學 and 系 in common');
    expect(guessCatalogDepartment(null, names), isNull);
  });
}
