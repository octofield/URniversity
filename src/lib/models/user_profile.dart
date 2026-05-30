class UserProfile {
  final String? username;
  final String? school;
  final String? department;
  final int? grade;
  final int? gradeSetYear;
  final int? avatarIndex;

  const UserProfile({
    this.username,
    this.school,
    this.department,
    this.grade,
    this.gradeSetYear,
    this.avatarIndex,
  });

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
    username: row['username'] as String?,
    school: row['school'] as String?,
    department: row['department'] as String?,
    grade: row['grade'] as int?,
    gradeSetYear: row['grade_set_year'] as int?,
    avatarIndex: row['avatar_index'] as int?,
  );

  Map<String, dynamic> toRow(String userId) => {
    'user_id': userId,
    'username': username,
    'school': school,
    'department': department,
    'grade': grade,
    'grade_set_year': gradeSetYear,
    'avatar_index': avatarIndex,
  };

  UserProfile copyWith({
    String? username,
    String? school,
    String? department,
    int? grade,
    int? gradeSetYear,
    int? avatarIndex,
  }) => UserProfile(
    username: username ?? this.username,
    school: school ?? this.school,
    department: department ?? this.department,
    grade: grade ?? this.grade,
    gradeSetYear: gradeSetYear ?? this.gradeSetYear,
    avatarIndex: avatarIndex ?? this.avatarIndex,
  );
}
