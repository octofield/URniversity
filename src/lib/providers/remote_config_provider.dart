import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// What the admin backend controls for everyone (D35, system_design.md §3-U):
// feature switches, one announcement and maintenance mode. Read at launch —
// guests too — and kept on the device, so an offline launch applies the last
// one seen (D38 app_config_cache)

// The switches the backend lists, in its order. A key missing from the stored
// flags is on, so a new switch never turns a feature off by itself
const kRemoteFeatures = [
  'timetable',
  'catalog_search',
  'credit_categories',
  'reviews',
  'onboarding_tour',
  'goal_templates',
];

class Announcement {
  final String id;
  final String text;
  // 'info' or 'warning'
  final String level;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const Announcement({required this.id, required this.text, this.level = 'info', this.startsAt, this.endsAt});

  bool showingAt(DateTime now) =>
      text.isNotEmpty && (startsAt == null || !now.isBefore(startsAt!)) && (endsAt == null || now.isBefore(endsAt!));

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        level: j['level'] as String? ?? 'info',
        startsAt: DateTime.tryParse(j['starts_at'] as String? ?? '')?.toLocal(),
        endsAt: DateTime.tryParse(j['ends_at'] as String? ?? '')?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'level': level,
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
      };
}

class RemoteConfig {
  final Map<String, bool> flags;
  final Announcement? announcement;
  final bool maintenance;
  final String maintenanceMessage;
  final DateTime? updatedAt;
  final String? updatedBy;

  const RemoteConfig({
    this.flags = const {},
    this.announcement,
    this.maintenance = false,
    this.maintenanceMessage = '',
    this.updatedAt,
    this.updatedBy,
  });

  bool on(String feature) => flags[feature] ?? true;

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    final maintenance = (j['maintenance'] as Map?)?.cast<String, dynamic>() ?? const {};
    final announcement = (j['announcement'] as Map?)?.cast<String, dynamic>();
    return RemoteConfig(
      flags: {for (final e in ((j['flags'] as Map?) ?? const {}).entries) e.key as String: e.value == true},
      announcement: announcement == null ? null : Announcement.fromJson(announcement),
      maintenance: maintenance['enabled'] == true,
      maintenanceMessage: maintenance['message'] as String? ?? '',
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal(),
      updatedBy: j['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'flags': flags,
        'announcement': announcement?.toJson(),
        'maintenance': {'enabled': maintenance, 'message': maintenanceMessage},
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'updated_by': updatedBy,
      };

  RemoteConfig copyWith({
    Map<String, bool>? flags,
    Announcement? Function()? announcement,
    bool? maintenance,
    String? maintenanceMessage,
  }) =>
      RemoteConfig(
        flags: flags ?? this.flags,
        announcement: announcement != null ? announcement() : this.announcement,
        maintenance: maintenance ?? this.maintenance,
        maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      );
}

// Where it comes from. An interface so widget tests, which never reach
// Supabase, hand in their own
abstract class RemoteConfigSource {
  Future<RemoteConfig?> fetch();
  Future<void> save(RemoteConfig config, String updatedBy);
}

class SupabaseRemoteConfigSource implements RemoteConfigSource {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<RemoteConfig?> fetch() async {
    final row = await _db.from('app_config').select().eq('id', 1).maybeSingle();
    return row == null ? null : RemoteConfig.fromJson(row);
  }

  @override
  Future<void> save(RemoteConfig config, String updatedBy) => _db.from('app_config').update({
        'flags': config.flags,
        'announcement': config.announcement?.toJson(),
        'maintenance': {'enabled': config.maintenance, 'message': config.maintenanceMessage},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': updatedBy,
      }).eq('id', 1);
}

final remoteConfigSourceProvider = Provider<RemoteConfigSource>((ref) => SupabaseRemoteConfigSource());

class RemoteConfigNotifier extends StateNotifier<RemoteConfig> {
  static const cacheKey = 'app_config_cache';

  RemoteConfigNotifier(this.ref) : super(const RemoteConfig()) {
    refresh();
  }

  final Ref ref;

  // The cached copy first, so the switches apply from the first frame, then
  // the live one over it
  Future<void> refresh() async {
    final p = await SharedPreferences.getInstance();
    final cached = p.getString(cacheKey);
    if (cached != null && mounted) {
      try {
        state = RemoteConfig.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (e) {
        // A parse fallback (hard rule 2): a damaged cache is skipped, the live
        // copy below replaces it
        debugPrint('[config] cache unreadable: $e');
      }
    }
    try {
      final live = await ref.read(remoteConfigSourceProvider).fetch();
      if (live == null || !mounted) return;
      state = live;
      await p.setString(cacheKey, jsonEncode(live.toJson()));
    } catch (e) {
      // Offline, or admin.sql not yet run: the last copy (or all on) stands.
      // Not a sync failure — nothing of the user's failed to save
      debugPrint('[config] not reachable: $e');
    }
  }

  // The backend's Save
  Future<void> save(RemoteConfig config, String updatedBy) async {
    await ref.read(remoteConfigSourceProvider).save(config, updatedBy);
    await refresh();
  }
}

final remoteConfigProvider = StateNotifierProvider<RemoteConfigNotifier, RemoteConfig>(
  (ref) => RemoteConfigNotifier(ref),
);

// Whether a switchable feature is on (kRemoteFeatures)
final featureOnProvider = Provider.family<bool, String>(
  (ref, feature) => ref.watch(remoteConfigProvider).on(feature),
);
