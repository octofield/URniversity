import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/grade_scale.dart';

// What the grades page needs to know about the degree (UC20): how many credits
// it takes, and which pass mark applies. Kept on the device (D31) and, for an
// account, in user_settings.graduation_credits / degree_level (D8-B), read and
// written by sync_provider on their own like the app style.
//
// Credits by category (§3-T) ride along: off unless the user turns it on, the
// entry year and department that pick the school's published requirements,
// the department's name in the catalog, and the user's own three numbers for
// a school that publishes none
class GradeSettings {
  final int graduationCredits;
  final DegreeLevel level;
  final bool categoriesEnabled;
  final int? entryYear;
  final String? requirementDepartment;
  final String? catalogDepartment;
  final int? requiredCredits;
  final int? generalCredits;
  final int? electiveCredits;

  const GradeSettings({
    this.graduationCredits = defaultCredits,
    this.level = DegreeLevel.bachelor,
    this.categoriesEnabled = false,
    this.entryYear,
    this.requirementDepartment,
    this.catalogDepartment,
    this.requiredCredits,
    this.generalCredits,
    this.electiveCredits,
  });

  // NTU's most common undergraduate requirement; asked the first time anyway
  static const defaultCredits = 128;

  // Fields that can be cleared take a function, as Course.copyWith does
  GradeSettings copyWith({
    int? graduationCredits,
    DegreeLevel? level,
    bool? categoriesEnabled,
    int? Function()? entryYear,
    String? Function()? requirementDepartment,
    String? Function()? catalogDepartment,
    int? Function()? requiredCredits,
    int? Function()? generalCredits,
    int? Function()? electiveCredits,
  }) =>
      GradeSettings(
        graduationCredits: graduationCredits ?? this.graduationCredits,
        level: level ?? this.level,
        categoriesEnabled: categoriesEnabled ?? this.categoriesEnabled,
        entryYear: entryYear != null ? entryYear() : this.entryYear,
        requirementDepartment: requirementDepartment != null ? requirementDepartment() : this.requirementDepartment,
        catalogDepartment: catalogDepartment != null ? catalogDepartment() : this.catalogDepartment,
        requiredCredits: requiredCredits != null ? requiredCredits() : this.requiredCredits,
        generalCredits: generalCredits != null ? generalCredits() : this.generalCredits,
        electiveCredits: electiveCredits != null ? electiveCredits() : this.electiveCredits,
      );
}

class GradeSettingsNotifier extends StateNotifier<GradeSettings> {
  static const creditsKey = 'graduation_credits';
  static const levelKey = 'degree_level';
  static const categoriesKey = 'credit_categories_enabled';
  static const entryYearKey = 'entry_year';
  static const requirementDepartmentKey = 'requirement_department';
  static const catalogDepartmentKey = 'catalog_department';
  static const requiredKey = 'credits_required';
  static const generalKey = 'credits_general';
  static const electiveKey = 'credits_elective';

  GradeSettingsNotifier() : super(const GradeSettings()) {
    _restore();
  }

  // Whether the user has confirmed these yet; the grades page asks once
  bool confirmed = false;

  // Whether credits by category was ever switched on here. Until then its
  // columns are not written, so a database without them (courses.sql not
  // re-run) fails nobody who does not use it
  bool categoriesTouched = false;

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    categoriesTouched = p.containsKey(categoriesKey);
    final credits = p.getInt(creditsKey);
    if (credits == null && !categoriesTouched) return;
    confirmed = credits != null;
    state = GradeSettings(
      graduationCredits: credits ?? GradeSettings.defaultCredits,
      level: degreeLevelFromName(p.getString(levelKey)),
      categoriesEnabled: p.getBool(categoriesKey) ?? false,
      entryYear: p.getInt(entryYearKey),
      requirementDepartment: p.getString(requirementDepartmentKey),
      catalogDepartment: p.getString(catalogDepartmentKey),
      requiredCredits: p.getInt(requiredKey),
      generalCredits: p.getInt(generalKey),
      electiveCredits: p.getInt(electiveKey),
    );
  }

  Future<void> set(GradeSettings settings) async {
    confirmed = true;
    if (settings.categoriesEnabled) categoriesTouched = true;
    state = settings;
    final p = await SharedPreferences.getInstance();
    await p.setInt(creditsKey, settings.graduationCredits);
    await p.setString(levelKey, settings.level.name);
    if (!categoriesTouched) return;
    await p.setBool(categoriesKey, settings.categoriesEnabled);
    Future<void> put(String key, Object? value) => switch (value) {
          null => p.remove(key),
          final int v => p.setInt(key, v),
          final String v => p.setString(key, v),
          _ => Future.value(),
        };
    await put(entryYearKey, settings.entryYear);
    await put(requirementDepartmentKey, settings.requirementDepartment);
    await put(catalogDepartmentKey, settings.catalogDepartment);
    await put(requiredKey, settings.requiredCredits);
    await put(generalKey, settings.generalCredits);
    await put(electiveKey, settings.electiveCredits);
  }
}

final gradeSettingsProvider = StateNotifierProvider<GradeSettingsNotifier, GradeSettings>(
  (ref) => GradeSettingsNotifier(),
);
