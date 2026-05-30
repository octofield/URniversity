class UserProfile {
  final String? username;
  final String? school;
  final String? department;
  // grade: base grade the user manually set
  final int? grade;
  // gradeSetYear: the academic-year number when `grade` was set
  // (e.g. 2025 means "this grade started in the Aug-2025 academic year")
  final int? gradeSetYear;

  const UserProfile({
    this.username,
    this.school,
    this.department,
    this.grade,
    this.gradeSetYear,
  });

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
    username: row['username'] as String?,
    school: row['school'] as String?,
    department: row['department'] as String?,
    grade: row['grade'] as int?,
    gradeSetYear: row['grade_set_year'] as int?,
  );

  Map<String, dynamic> toRow(String userId) => {
    'id': userId,
    'username': username,
    'school': school,
    'department': department,
    'grade': grade,
    'grade_set_year': gradeSetYear,
  };

  UserProfile copyWith({
    String? username,
    String? school,
    String? department,
    int? grade,
    int? gradeSetYear,
  }) => UserProfile(
    username: username ?? this.username,
    school: school ?? this.school,
    department: department ?? this.department,
    grade: grade ?? this.grade,
    gradeSetYear: gradeSetYear ?? this.gradeSetYear,
  );
}
