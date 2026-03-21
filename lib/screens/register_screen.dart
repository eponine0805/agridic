import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../utils/app_colors.dart';
import 'register_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ─── Validation ─────────────────────────────────────────────────────

  bool _validateName() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a display name');
      return false;
    }
    return true;
  }

  // ─── Email / Password 登録 ──────────────────────────────────────────

  Future<void> _registerWithEmail() async {
    if (!_validateName()) return;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _busy = true; _error = null; });

    final err = await context.read<UserPrefs>().register(
      email, pass, _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _busy = false; _error = err; });
      return;
    }
    await _goToProfileSetup();
  }

  // ─── Google 登録 ────────────────────────────────────────────────────

  Future<void> _registerWithGoogle() async {
    if (!_validateName()) return;
    setState(() { _busy = true; _error = null; });

    final err = await context.read<UserPrefs>().signInWithGoogle();
    if (!mounted) return;
    if (err != null) {
      setState(() { _busy = false; _error = err; });
      return;
    }

    // ユーザーが入力した名前でGoogle名を上書き
    final enteredName = _nameCtrl.text.trim();
    if (enteredName.isNotEmpty) {
      await context.read<UserPrefs>().updateDisplayName(enteredName);
    }
    if (!mounted) return;
    await _goToProfileSetup();
  }

  // ─── プロフィール設定画面へ ──────────────────────────────────────────

  Future<void> _goToProfileSetup() async {
    setState(() => _busy = false);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterProfileScreen()),
    );
    // RegisterProfileScreen が popUntil(first) で全部 pop するので
    // ここには通常戻ってこない
  }

  // ─── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Create Account',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── ステップ表示 ──
              Row(
                children: [
                  _StepChip(step: 1, label: 'Account', active: true),
                  const SizedBox(width: 6),
                  const Expanded(
                      child: Divider(color: AppColors.textSecondary)),
                  const SizedBox(width: 6),
                  _StepChip(step: 2, label: 'Profile', active: false),
                ],
              ),
              const SizedBox(height: 28),

              // ── 名前フィールド（必須・どちらの方法でも使用）──
              _field(
                controller: _nameCtrl,
                label: 'Display name',
                hint: 'What should we call you?',
                icon: Icons.person_outlined,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 24),

              // ── Email / Password セクション ──
              _sectionLabel('Sign up with email'),
              const SizedBox(height: 12),
              _field(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _passCtrl,
                label: 'Password (min. 6 chars)',
                icon: Icons.lock_outlined,
                obscure: _obscurePass,
                toggleObscure: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
              const SizedBox(height: 16),
              _primaryBtn(
                label: 'Create account',
                onTap: _busy ? null : _registerWithEmail,
              ),

              // ── OR セパレーター ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),

              // ── Google ボタン ──
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _busy ? null : _registerWithGoogle,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleIcon(),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF444444),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              // ── エラー表示 ──
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorBox(message: _error!),
              ],

              // ── ローディング ──
              if (_busy) ...[
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              ],

              const SizedBox(height: 32),

              // ── ログインへのリンク ──
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Sign in',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── ヘルパーウィジェット ──────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3));
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? toggleObscure,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: toggleObscure,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      ),
    );
  }

  Widget _primaryBtn({required String label, VoidCallback? onTap}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
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
          backgroundColor: color,
          child: Text('$step',
              style: const TextStyle(color: Colors.white, fontSize: 11)),
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

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Minimal Google "G" icon (copied from login_screen)
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final cx = r, cy = r;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, -1.57, 2.09, false,
        Paint()
          ..color = const Color(0xFF4285F4)
          ..strokeWidth = size.width * 0.18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt);
    canvas.drawArc(rect, 0.52, 1.05, false,
        Paint()
          ..color = const Color(0xFFEA4335)
          ..strokeWidth = size.width * 0.18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt);
    canvas.drawArc(rect, 1.57, 1.05, false,
        Paint()
          ..color = const Color(0xFFFBBC05)
          ..strokeWidth = size.width * 0.18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt);
    canvas.drawArc(rect, 2.62, 1.05, false,
        Paint()
          ..color = const Color(0xFF34A853)
          ..strokeWidth = size.width * 0.18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt);
    canvas.drawCircle(Offset(cx, cy), r * 0.65, Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(
            cx, cy - size.height * 0.08, r * 0.9, size.height * 0.16),
        Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(_) => false;
}
