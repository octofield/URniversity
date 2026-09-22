import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/input_limits.dart';
import '../../core/sign_in_failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import 'auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // The same account either way, so registering with Google is the call the
  // sign-in page already makes — Supabase creates the user on first sign-in
  Future<void> _googleRegister() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'com.octofield.urniversity://login-callback',
      );
    } catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(signInFailureMessage(signInFailureFrom(e), s))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final s = ref.read(stringsProvider);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (email.isEmpty || password.isEmpty) return;
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordMismatch)),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordTooShort)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (mounted) {
        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.checkVerificationEmail)),
          );
        }
        Navigator.pop(context);
      }
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.createAccount,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [LengthLimitingTextInputFormatter(InputLimits.email)],
          decoration: InputDecoration(
            labelText: s.emailLabel,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          inputFormatters: [LengthLimitingTextInputFormatter(InputLimits.password)],
          decoration: InputDecoration(
            labelText: s.passwordLabelWithHint,
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_showPassword,
          inputFormatters: [LengthLimitingTextInputFormatter(InputLimits.password)],
          decoration: InputDecoration(
            labelText: s.confirmPasswordLabel,
            prefixIcon: const Icon(Icons.lock_outlined),
          ),
          onSubmitted: (_) => _register(),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.register),
          ),
        ),
        AuthDivider(s: s),
        GoogleAuthButton(
          label: s.signUpWithGoogle,
          onPressed: _loading ? null : _googleRegister,
        ),
        const SizedBox(height: AppSpacing.sm),
        AuthSwitchLine(
          question: s.haveAccountAlready,
          action: s.login,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    return AuthLayout(
      title: s.createAccount,
      subtitle: s.registerTagline,
      bullets: [s.authBulletTasks, s.authBulletTargets, s.authBulletVisions],
      card: card,
    );
  }
}
