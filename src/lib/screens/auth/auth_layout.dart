import 'package:flutter/material.dart';

import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_strings.dart';

// The shell the sign-in and register pages share (design A, 2026-09-23
// canvas): a warm brand area with the form on a card over it.
//
// Phone: the brand area is a 250px hero and the card overlaps its bottom edge.
// Desktop: the brand area takes the left half and the card sits centred in the
// right one. Both pages go through here so they cannot drift apart.

// Google's blue on the G glyph — enough to read as Google without shipping the
// full four-colour mark as an asset
const Color _googleBlue = Color(0xFF4285F4);

class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  // Shown beside the form on desktop, where there is room to say what the app
  // is for; the phone hero has no space for them
  final List<String> bullets;
  final Widget card;
  // Under the card: the guest entry on the sign-in page, nothing on register
  final Widget? footer;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.card,
    this.bullets = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            Expanded(
              child: _BrandPanel(
                title: title,
                subtitle: subtitle,
                bullets: bullets,
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Card(child: card),
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(title: title, subtitle: subtitle),
            // Pulled up over the hero's lower edge
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal),
                child: _Card(child: card),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// The app's mark: the launcher icon itself, as the splash screen shows it
class AppMark extends StatelessWidget {
  final double size;

  const AppMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/app_icon.png',
      width: size,
      height: size,
    );
  }
}

// Soft category-coloured circles behind the brand area. Decorative only, so
// they never take a pointer
class _Bubbles extends StatelessWidget {
  final List<({double left, double top, double size, Color color})> bubbles;

  const _Bubbles({required this.bubbles});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final b in bubbles)
            Positioned(
              left: b.left,
              top: b.top,
              child: Container(
                width: b.size,
                height: b.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: b.color.withValues(alpha: 0.14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Hero({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryLight, AppColors.background],
        ),
      ),
      child: Stack(
        children: [
          const _Bubbles(bubbles: [
            (left: 254, top: -6, size: 92, color: AppColors.categoryExchange),
            (left: 30, top: 90, size: 60, color: AppColors.categoryCert),
            (left: 232, top: 132, size: 36, color: AppColors.categoryPerformance),
          ]),
          Positioned(
            left: AppSpacing.pageHorizontal + 4,
            bottom: 56,
            right: AppSpacing.pageHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppMark(),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _BrandPanel({
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primaryLight, AppColors.background],
        ),
      ),
      child: Stack(
        children: [
          const _Bubbles(bubbles: [
            (left: 360, top: 40, size: 180, color: AppColors.categoryExchange),
            (left: 60, top: 460, size: 140, color: AppColors.categoryCert),
            (left: 300, top: 580, size: 80, color: AppColors.categoryPerformance),
            (left: 170, top: 180, size: 52, color: AppColors.categoryCompetition),
          ]),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppMark(size: 72),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final line in bullets)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            line,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// "or" with a rule either side
class AuthDivider extends StatelessWidget {
  final AppStrings s;

  const AuthDivider({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              s.orDivider,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class GoogleAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GoogleAuthButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.g_mobiledata, size: 26, color: _googleBlue),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}

// "Already have an account? Sign in", with the action in the app's colour
class AuthSwitchLine extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onPressed;

  const AuthSwitchLine({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          child: Text(
            action,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
