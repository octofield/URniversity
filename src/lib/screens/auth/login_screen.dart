import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/guest_provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/settings_provider.dart';
import 'register_screen.dart';
import '../../widgets/responsive_body.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'com.octofield.urniversity://login-callback',
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendResetLink() async {
    final s = ref.read(stringsProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(s: s, initialEmail: _emailCtrl.text.trim()),
    );
    if (result == null || result.isEmpty) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        result,
        // Same scheme the Google flow already registers in AndroidManifest
        redirectTo: kIsWeb ? Uri.base.origin : 'com.octofield.urniversity://login-callback',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.resetEmailSent)),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 80),
        Text(
          'URniversity',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          s.login,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: s.emailLabel,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: s.passwordLabel,
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          onSubmitted: (_) => _login(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : _sendResetLink,
            child: Text(s.forgotPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.login),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(s.orDivider,
                  style: const TextStyle(color: AppColors.textTertiary)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata, size: 22),
            label: Text(s.signInWithGoogle),
            onPressed: _loading ? null : _googleLogin,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.noAccountYet),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: Text(s.register),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Consumer(
          builder: (ctx, ref, _) {
            final isGuest = ref.watch(guestModeProvider);
            final pending = ref.watch(pendingGuestLoginProvider);
            if (isGuest && pending) {
              return TextButton(
                onPressed: () =>
                    ref.read(pendingGuestLoginProvider.notifier).state = false,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                ),
                child: Text(s.backToGuestMode),
              );
            }
            return TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      await ref.read(guestModeProvider.notifier).enable();
                      if (mounted) setState(() => _loading = false);
                    },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textTertiary,
              ),
              child: Text(s.tryAsGuest),
            );
          },
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
          ),
          child: ResponsiveBody(
            maxWidth: ResponsiveBody.formWidth,
            child: form,
          ),
        ),
      ),
    );
  }
}


// Asks which address the reset link should go to. Pre-filled from the login
// field so the common case is one tap
class _ForgotPasswordDialog extends StatefulWidget {
  final AppStrings s;
  final String initialEmail;
  const _ForgotPasswordDialog({required this.s, required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.forgotPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.resetPasswordHint,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: s.emailLabel),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(s.sendResetLink),
        ),
      ],
    );
  }
}
