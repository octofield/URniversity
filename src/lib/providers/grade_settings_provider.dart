import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/grade_scale.dart';

// What the grades page needs to know about the degree (UC20): how many credits
// it takes, and which pass mark applies. Kept on the device (D31) and, for an
// account, in user_settings.graduation_credits / degree_level (D8-B), read and
// written by sync_provider on their own like the app style
class GradeSettings {
  final int graduationCredits;
  final DegreeLevel level;

  const GradeSettings({this.graduationCredits = defaultCredits, this.level = DegreeLevel.bachelor});

  // NTU's most common undergraduate requirement; asked the first time anyway
  static const defaultCredits = 128;
}

class GradeSettingsNotifier extends StateNotifier<GradeSettings> {
  static const creditsKey = 'graduation_credits';
  static const levelKey = 'degree_level';

  GradeSettingsNotifier() : super(const GradeSettings()) {
    _restore();
  }

  // Whether the user has confirmed these yet; the grades page asks once
  bool confirmed = false;

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final credits = p.getInt(creditsKey);
    if (credits == null) return;
    confirmed = true;
    state = GradeSettings(graduationCredits: credits, level: degreeLevelFromName(p.getString(levelKey)));
  }

  Future<void> set(GradeSettings settings) async {
    confirmed = true;
    state = settings;
    final p = await SharedPreferences.getInstance();
    await p.setInt(creditsKey, settings.graduationCredits);
    await p.setString(levelKey, settings.level.name);
  }
}

final gradeSettingsProvider = StateNotifierProvider<GradeSettingsNotifier, GradeSettings>(
  (ref) => GradeSettingsNotifier(),
);
