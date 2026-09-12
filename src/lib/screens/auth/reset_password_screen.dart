import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/password_recovery_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/responsive_body.dart';

// Shown when the user opens a password-reset link. They already hold a valid
// recovery session at this point, so the only thing left is to set a password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    final password = _passwordCtrl.text;
    if (password != _confirmCtrl.text) {
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
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: password));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordUpdated)),
      );
      // Leaving recovery mode hands the user back to _AuthGate, which now sees
      // an ordinary signed-in session
      ref.read(passwordRecoveryProvider.notifier).state = false;
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

  // Abandoning the reset must also drop the recovery session, otherwise the link
  // would leave a signed-in account behind for whoever opened it
  Future<void> _cancel() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) ref.read(passwordRecoveryProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.setNewPassword),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _loading ? null : _cancel,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.lg,
          ),
          child: ResponsiveBody(
            maxWidth: ResponsiveBody.formWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: s.newPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: s.confirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined),
                  ),
                  onSubmitted: (_) => _loading ? null : _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
