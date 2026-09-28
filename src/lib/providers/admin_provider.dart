import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'guest_provider.dart';

// The admin backend's data (/admin, system_design.md §2-O). All of it comes
// from the SECURITY DEFINER functions in supabase/admin.sql, which refuse
// anyone not in the admins table; none of it is anybody's content

Map<String, int> _counts(Object? json) => {
      for (final e in ((json as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt(),
    };

// Numbers per day for the last 30 days, oldest first, with the empty days in
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

List<int> last30(Map<String, int> byDay, DateTime today) => [
      for (var i = 29; i >= 0; i--)
        byDay[_isoDay(_day(today).subtract(Duration(days: i)))] ?? 0,
    ];

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FeatureUsage {
  final int total;
  final int users;
  final Map<String, int> daily;

  const FeatureUsage({this.total = 0, this.users = 0, this.daily = const {}});

  factory FeatureUsage.fromJson(Map<String, dynamic> j) => FeatureUsage(
        total: (j['total'] as num?)?.toInt() ?? 0,
        users: (j['users'] as num?)?.toInt() ?? 0,
        daily: _counts(j['daily']),
      );
}

class ErrorGroup {
  final String where;
  final String? code;
  final int count;

  const ErrorGroup({required this.where, this.code, required this.count});
}

class ErrorReport {
  final DateTime at;
  final String where;
  final String? code;
  final String message;
  final String? platform;

  const ErrorReport({required this.at, required this.where, this.code, required this.message, this.platform});
}

class AdminStats {
  final int users;
  final int usersToday;
  final Map<String, int> usersDaily;
  final List<({String name, int count})> schools;
  final int dau;
  final int wau;
  final int mau;
  final Map<String, int> activeDaily;
  // By table name: tasks, semester_goals, future_goals, journals, inspirations,
  // courses, reviews
  final Map<String, FeatureUsage> features;
  final Map<String, int> styles;
  final Map<String, int> languages;
  final int creditCategories;
  final List<ErrorGroup> errorGroups;
  final List<ErrorReport> recentErrors;

  const AdminStats({
    this.users = 0,
    this.usersToday = 0,
    this.usersDaily = const {},
    this.schools = const [],
    this.dau = 0,
    this.wau = 0,
    this.mau = 0,
    this.activeDaily = const {},
    this.features = const {},
    this.styles = const {},
    this.languages = const {},
    this.creditCategories = 0,
    this.errorGroups = const [],
    this.recentErrors = const [],
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> part(String key) => ((j[key] as Map?) ?? const {}).cast<String, dynamic>();
    final users = part('users');
    final active = part('active');
    final settings = part('settings');
    final errors = part('errors');
    return AdminStats(
      users: (users['total'] as num?)?.toInt() ?? 0,
      usersToday: (users['today'] as num?)?.toInt() ?? 0,
      usersDaily: _counts(users['daily']),
      schools: [
        for (final s in (users['schools'] as List?) ?? const [])
          (name: (s as Map)['name'] as String, count: (s['count'] as num).toInt()),
      ],
      dau: (active['dau'] as num?)?.toInt() ?? 0,
      wau: (active['wau'] as num?)?.toInt() ?? 0,
      mau: (active['mau'] as num?)?.toInt() ?? 0,
      activeDaily: _counts(active['daily']),
      features: {
        for (final e in part('features').entries)
          e.key: FeatureUsage.fromJson((e.value as Map).cast<String, dynamic>()),
      },
      styles: _counts(settings['styles']),
      languages: _counts(settings['languages']),
      creditCategories: (settings['credit_categories'] as num?)?.toInt() ?? 0,
      errorGroups: [
        for (final g in (errors['groups'] as List?) ?? const [])
          ErrorGroup(
            where: (g as Map)['where'] as String? ?? '',
            code: g['code'] as String?,
            count: (g['count'] as num).toInt(),
          ),
      ],
      recentErrors: [
        for (final r in (errors['recent'] as List?) ?? const [])
          ErrorReport(
            at: DateTime.parse((r as Map)['at'] as String).toLocal(),
            where: r['where'] as String? ?? '',
            code: r['code'] as String?,
            message: r['message'] as String? ?? '',
            platform: r['platform'] as String?,
          ),
      ],
    );
  }
}

class AdminUser {
  final String id;
  final String? email;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final bool disabled;
  final String? username;
  final String? school;
  final String? department;

  const AdminUser({
    required this.id,
    this.email,
    required this.createdAt,
    this.lastSignInAt,
    this.disabled = false,
    this.username,
    this.school,
    this.department,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['user_id'] as String,
        email: j['email'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        lastSignInAt: DateTime.tryParse(j['last_sign_in_at'] as String? ?? '')?.toLocal(),
        disabled: j['disabled'] as bool? ?? false,
        username: j['username'] as String?,
        school: j['school'] as String?,
        department: j['department'] as String?,
      );
}

// An interface so widget tests, which never reach Supabase, hand in their own
abstract class AdminSource {
  Future<bool> isAdmin();
  Future<AdminStats> stats();
  Future<List<AdminUser>> users(String search, int page);
  Future<void> setDisabled(String userId, bool disabled);
}

class SupabaseAdminSource implements AdminSource {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<bool> isAdmin() async => await _db.rpc('is_admin') == true;

  @override
  Future<AdminStats> stats() async =>
      AdminStats.fromJson(((await _db.rpc('admin_stats')) as Map).cast<String, dynamic>());

  @override
  Future<List<AdminUser>> users(String search, int page) async {
    final rows = await _db.rpc('admin_list_users', params: {'search': search, 'page': page});
    return [for (final r in rows as List<dynamic>) AdminUser.fromJson((r as Map).cast<String, dynamic>())];
  }

  @override
  Future<void> setDisabled(String userId, bool disabled) =>
      _db.rpc('admin_set_user_disabled', params: {'target': userId, 'disabled': disabled});
}

final adminSourceProvider = Provider<AdminSource>((ref) => SupabaseAdminSource());

// Whether the signed-in account is an admin: the Settings row and /admin.
// A guest never is, and an unreachable check (offline, admin.sql not yet run)
// reads as no — the backend's own functions refuse anyone else regardless
final isAdminProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(guestModeProvider)) return false;
  // Re-asked on every sign-in and sign-out
  ref.watch(authStateProvider);
  if (ref.watch(currentUserProvider) == null) return false;
  try {
    return await ref.watch(adminSourceProvider).isAdmin();
  } catch (e) {
    debugPrint('[admin] check failed: $e');
    return false;
  }
});

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>(
  (ref) => ref.watch(adminSourceProvider).stats(),
);

final adminUsersProvider = FutureProvider.autoDispose.family<List<AdminUser>, ({String search, int page})>(
  (ref, args) => ref.watch(adminSourceProvider).users(args.search, args.page),
);
