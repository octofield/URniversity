import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/avatars.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/profile_provider.dart';

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _usernameCtrl = TextEditingController();
  int? _selectedAvatar;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _usernameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(profileProvider.notifier).setupProfile(name, _selectedAvatar);
    // _AuthGate rebuilds to HomeScreen once profile.username is set.
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final username = _usernameCtrl.text;
    final canSave = username.trim().isNotEmpty && !_loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal, 40,
            AppSpacing.pageHorizontal, AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '設定個人資料',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '之後可在帳號設定中修改',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 36),

              // Avatar preview
              Center(
                child: AppAvatars.build(
                  avatarIndex: _selectedAvatar,
                  avatarUrl: null,
                  initial: username.isNotEmpty ? username[0].toUpperCase() : '?',
                  radius: 48,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                '選擇頭像',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (int i = 0; i < AppAvatars.presets.length; i++)
                    _AvatarOption(
                      index: i,
                      isSelected: _selectedAvatar == i,
                      onTap: () => setState(() {
                        _selectedAvatar = _selectedAvatar == i ? null : i;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              TextField(
                controller: _usernameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '使用者名稱',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('完成'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarOption({
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: AppAvatars.build(
          avatarIndex: index,
          avatarUrl: null,
          initial: '',
          radius: 24,
        ),
      ),
    );
  }
}
