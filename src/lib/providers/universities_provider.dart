import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/taiwan_universities.dart';

class UniversitiesState {
  const UniversitiesState();

  List<String> get universities => taiwanUniversities;

  List<String> departmentsFor(String school) {
    if (school.isNotEmpty) {
      return universityDepartments[school] ?? [];
    }
    return universityDepartments.values.expand((d) => d).toSet().toList()..sort();
  }
}

final universitiesProvider = Provider<UniversitiesState>((_) => const UniversitiesState());
