import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _resetIfNeeded();
  }

  Future<void> _resetIfNeeded() async {
    final userPrefs = context.read<UserPrefs>();
    if (userPrefs.unreadCount > 0) {
      setState(() => _resetting = true);
      await userPrefs.resetLikeCount();
      if (mounted) setState(() => _resetting = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final likeCount = context.watch<UserPrefs>().unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Notifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
      body: _resetting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : likeCount <= 0
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: AppColors.danger, size: 20),
                      ),
                      title: Text(
                        '$likeCount new like${likeCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                    ),
                  ],
                ),
    );
  }
}

// ─── Admin broadcast dialog ───────────────────────────────────────────────

class AdminBroadcastDialog extends StatefulWidget {
  const AdminBroadcastDialog({super.key});

  @override
  State<AdminBroadcastDialog> createState() => _AdminBroadcastDialogState();
}

class _AdminBroadcastDialogState extends State<AdminBroadcastDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final userId = context.read<UserPrefs>().userId;
    try {
      await FirebaseService.sendBroadcast(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        sentBy: userId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _sending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send notification to all users',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Title',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Message (optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, size: 18),
              label: const Text('Send to all users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
