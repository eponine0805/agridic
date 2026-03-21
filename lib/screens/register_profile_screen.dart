import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../utils/app_colors.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/post_card.dart';

class RegisterProfileScreen extends StatefulWidget {
  const RegisterProfileScreen({super.key});

  @override
  State<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends State<RegisterProfileScreen> {
  final _bioCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    final bio = _bioCtrl.text.trim();
    if (bio.isNotEmpty) {
      await context.read<UserPrefs>().updateBio(bio);
    }
    if (!mounted) return;
    // LoginScreen まで全部 pop → _StartupRouter が続きを処理
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _skip() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = context.watch<UserPrefs>();
    final avatarBase64 = userPrefs.avatarBase64;
    final userName = userPrefs.userName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        automaticallyImplyLeading: false, // 戻るボタン非表示（登録フロー）
        title: const Text('Set up your profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _skip,
            child: const Text('Skip',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── ステップ表示 ──
              Row(
                children: [
                  _StepChip(step: 1, label: 'Account', active: false),
                  const SizedBox(width: 6),
                  const Expanded(
                      child: Divider(color: AppColors.primary, thickness: 1.5)),
                  const SizedBox(width: 6),
                  _StepChip(step: 2, label: 'Profile', active: true),
                ],
              ),

              const SizedBox(height: 36),

              // ── アバターエリア ──
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => showAvatarEditor(context),
                      child: Stack(
                        children: [
                          avatarBase64.isNotEmpty
                              ? AvatarImage(base64: avatarBase64, radius: 52)
                              : CircleAvatar(
                                  radius: 52,
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.12),
                                  child: Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 40,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                          // カメラアイコンバッジ
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.background, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to add a photo',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Bio フィールド ──
              const Text(
                'Bio  (optional)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bioCtrl,
                maxLines: 4,
                maxLength: 160,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tell others a bit about yourself…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 28),

              // ── Done ボタン ──
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Done',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),

              // ── Skip リンク ──
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _skip,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final int step;
  final String label;
  final bool active;
  const _StepChip(
      {required this.step, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.grey[400]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: active ? AppColors.primary : Colors.grey[300]!,
          child: active
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : Text('$step',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 11)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                color: color)),
      ],
    );
  }
}
