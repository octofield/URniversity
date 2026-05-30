import 'package:flutter/material.dart';
import 'theme/app_colors.dart';

class AvatarPreset {
  final Color color;
  final IconData icon;
  const AvatarPreset({required this.color, required this.icon});
}

class AppAvatars {
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
        child: Icon(p.icon, color: Colors.white, size: radius * 0.85),
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
          color: Colors.white,
        ),
      ),
    );
  }
}
