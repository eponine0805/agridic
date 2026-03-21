import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_notification.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import 'detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _navigatingPostId; // 投稿フェッチ中のpostId（ローディング表示用）

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final userPrefs = context.read<UserPrefs>();

    // キャッシュが有効かつ強制更新でなければキャッシュを使う
    if (!forceRefresh && userPrefs.notifCacheValid) {
      if (mounted) {
        setState(() {
          _notifications = userPrefs.cachedNotifications ?? [];
          _loading = false;
        });
      }
      return;
    }

    setState(() => _loading = true);
    final userId = userPrefs.userId;
    try {
      final personal = await FirebaseService.fetchNotifications(userId);
      final broadcasts = await FirebaseService.fetchBroadcasts();

      final all = [...personal, ...broadcasts];
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // キャッシュを更新
      userPrefs.setCachedNotifications(all);
      _notifications = all;

      // 個人通知を既読に → unreadCount をリセット
      final unread =
          personal.where((n) => !n.isRead).map((n) => n.id).toList();
      if (unread.isNotEmpty) {
        await FirebaseService.markNotificationsRead(userId, unread);
        userPrefs.resetUnreadCount();
      }
    } catch (e) {
      debugPrint('[NotificationsScreen] load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 通知タップ時に対象の投稿詳細画面へ遷移する
  Future<void> _openPost(String postId) async {
    if (_navigatingPostId != null) return;
    setState(() => _navigatingPostId = postId);
    try {
      // メモリ上のキャッシュを先に確認して不要な Firestore 読み込みを避ける
      final appState = context.read<AppState>();
      Post? post = appState.posts.cast<Post?>().firstWhere(
            (p) => p?.postId == postId,
            orElse: () => null,
          );
      post ??= await FirebaseService.fetchPostById(postId);
      if (!mounted) return;
      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('投稿が見つかりません（削除済みの可能性があります）'),
          backgroundColor: AppColors.textSecondary,
        ));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: appState),
              ChangeNotifierProvider.value(value: context.read<UserPrefs>()),
            ],
            child: DetailScreen(post: post!),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationsScreen] _openPost failed: $e');
    } finally {
      if (mounted) setState(() => _navigatingPostId = null);
    }
  }

  IconData _iconForType(String type) => switch (type) {
        'like' => Icons.favorite,
        _ => Icons.campaign_outlined,
      };

  Color _colorForType(String type) => switch (type) {
        'like' => AppColors.danger,
        'dict_added' => AppColors.primary,
        _ => AppColors.accent,
      };

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inSeconds < 60) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Notifications',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _load(forceRefresh: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
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
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: AppColors.divider, indent: 64),
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return _NotificationTile(
                      notification: n,
                      icon: _iconForType(n.type),
                      iconColor: _colorForType(n.type),
                      timeText: _timeAgo(n.timestamp),
                      isNavigating: _navigatingPostId == n.postId,
                      onTap: n.postId != null
                          ? () => _openPost(n.postId!)
                          : null,
                    );
                  },
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final Color iconColor;
  final String timeText;
  final VoidCallback? onTap;
  final bool isNavigating;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.timeText,
    this.onTap,
    this.isNavigating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: notification.isRead
          ? Colors.transparent
          : AppColors.primary.withOpacity(0.04),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: isNavigating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
              : Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body.isNotEmpty)
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 2),
            Row(children: [
              Text(timeText,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              if (notification.postId != null) ...[
                const SizedBox(width: 6),
                const Text('· 投稿を見る',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.primary)),
              ],
            ]),
          ],
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}

// ─── 管理者ブロードキャスト送信ダイアログ ──────────────────────────────

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
