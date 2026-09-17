import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

// What the app shows while it connects, between the system splash and the
// first real screen. Same ground colour as the native splash
// (res/values/widget_colors.xml splash_background), so the hand-off is
// invisible; the name is here because the Android 12 splash API draws an icon
// and nothing else.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/app_icon.png', width: 96, height: 96),
            const SizedBox(height: AppSpacing.md),
            // A brand name, the same in every language
            const Text(
              'URniversity',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
