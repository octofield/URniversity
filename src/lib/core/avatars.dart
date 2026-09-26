import 'package:flutter/material.dart';
import 'theme/app_colors.dart';

class AvatarPreset {
  final Color color;
  final IconData icon;
  const AvatarPreset({required this.color, required this.icon});
}

class AppAvatars {
  // The first ten keep their place for good: avatar_index is stored per user,
  // so reordering them would change everyone's avatar. Later ones use the app's
  // own category palette rather than Material's brighter defaults.
  static const List<AvatarPreset> presets = [
    AvatarPreset(color: Color(0xFF6366F1), icon: Icons.auto_awesome),
    AvatarPreset(color: Color(0xFF8B5CF6), icon: Icons.favorite_border),
    AvatarPreset(color: Color(0xFF06B6D4), icon: Icons.wb_sunny),
    AvatarPreset(color: Color(0xFF10B981), icon: Icons.eco),
    AvatarPreset(color: Color(0xFFF59E0B), icon: Icons.bolt),
    AvatarPreset(color: Color(0xFFEF4444), icon: Icons.local_fire_department),
    AvatarPreset(color: Color(0xFF64748B), icon: Icons.security),
    AvatarPreset(color: Color(0xFFEC4899), icon: Icons.music_note),
    AvatarPreset(color: Color(0xFF0EA5E9), icon: Icons.explore),
    AvatarPreset(color: Color(0xFF84CC16), icon: Icons.rocket_launch),
    // Study
    AvatarPreset(color: AppColors.categoryExchange, icon: Icons.menu_book),
    AvatarPreset(color: AppColors.categoryCert, icon: Icons.school),
    AvatarPreset(color: AppColors.categoryIntern, icon: Icons.science),
    // The original caramel, fixed: an avatar is the user's pick and keeps its
    // colour whatever style the app wears
    AvatarPreset(color: Color(0xFFA07850), icon: Icons.edit_note),
    // Making things
    AvatarPreset(color: AppColors.categoryCompetition, icon: Icons.brush),
    AvatarPreset(color: AppColors.categoryPerformance, icon: Icons.camera_alt),
    AvatarPreset(color: Color(0xFF6B5CA5), icon: Icons.code),
    AvatarPreset(color: Color(0xFF2E9E8E), icon: Icons.piano),
    // Out and about
    AvatarPreset(color: Color(0xFF3A6EA5), icon: Icons.directions_run),
    AvatarPreset(color: Color(0xFF2B8C8C), icon: Icons.sports_basketball),
    AvatarPreset(color: Color(0xFFC4622D), icon: Icons.flight_takeoff),
    AvatarPreset(color: Color(0xFF3D7A3D), icon: Icons.terrain),
    // Comforts
    AvatarPreset(color: Color(0xFFD98BA8), icon: Icons.local_cafe),
    AvatarPreset(color: AppColors.categoryOther, icon: Icons.pets),
  ];

  static Widget build({
    required int? avatarIndex,
    required String? avatarUrl,
    required String initial,
    required double radius,
  }) {
    if (avatarIndex != null && avatarIndex >= 0 && avatarIndex < presets.length) {
      final p = presets[avatarIndex];
      return CircleAvatar(
        radius: radius,
        backgroundColor: p.color,
        child: Icon(p.icon, color: AppColors.textOnPrimary, size: radius * 0.85),
      );
    }
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
