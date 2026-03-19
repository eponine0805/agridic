import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../models/report_reason.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import '../screens/comment_sheet.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final userPrefs = context.watch<UserPrefs>();
    final isOfficial = post.isOfficial;
    final isLiked = post.likedBy.contains(userPrefs.userId);
    final isAdmin = userPrefs.isAdmin;
    final isOwner = post.userId.isNotEmpty && post.userId == userPrefs.userId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOfficial ? AppColors.officialBg : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: isOfficial
              ? const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(post: post),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOfficial) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.star,
                                  color: AppColors.verifiedGold, size: 14),
                              const SizedBox(width: 2),
                              const Text('Official',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.verifiedGold,
                                      fontWeight: FontWeight.bold)),
                            ] else if (post.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.primary, size: 14),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              state.formatTime(post.timestamp),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        _RoleBadge(role: post.userRole),
                      ],
                    ),
                  ),
                  // Three dots menu
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 16, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      itemBuilder: (_) => [
                        if (isOwner || isAdmin) ...[
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 16, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Delete post',
                                    style:
                                        TextStyle(color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
                        if (isAdmin) ...[
                          PopupMenuItem(
                            value: 'star',
                            child: Row(
                              children: [
                                Icon(
                                  post.isOfficial
                                      ? Icons.star
                                      : Icons.star_outline,
                                  size: 16,
                                  color: AppColors.verifiedGold,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  post.isOfficial
                                      ? 'Unstar post'
                                      : 'Star post',
                                  style: const TextStyle(
                                      color: AppColors.verifiedGold),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'dict',
                            child: Row(
                              children: [
                                Icon(
                                  post.inDictionary
                                      ? Icons.menu_book
                                      : Icons.menu_book_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  post.inDictionary
                                      ? 'Remove from dictionary'
                                      : 'Add to dictionary',
                                  style: const TextStyle(
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!isOwner)
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined,
                                    size: 16, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Report post',
                                    style: TextStyle(color: AppColors.danger)),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (v) {
                        if (v == 'report') {
                          _showReportDialog(context, userPrefs.userId);
                        } else if (v == 'dict') {
                          _toggleDictionary(context);
                        } else if (v == 'delete') {
                          _confirmDelete(context);
                        } else if (v == 'star') {
                          _toggleStar();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Content
              Text(
                post.content.textShort,
                style: const TextStyle(fontSize: 14),
                maxLines: isOfficial ? 2 : 5,
                overflow: TextOverflow.ellipsis,
              ),
              // Thumbnail image
              if (post.content.imageLow.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Thumbnail(url: post.content.imageLow),
              ],
              // Official CTA
              if (isOfficial) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Read more →',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                    if (post.dictCrop.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _Tag(label: post.dictCrop),
                    ],
                    if (post.dictCategory.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _Tag(label: post.dictCategory),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 6),
              const Divider(height: 1, color: AppColors.divider),
              // Action bar
              Row(
                children: [
                  _ActionBtn(
                    icon: Icons.chat_bubble_outline,
                    label: '',
                    color: AppColors.textSecondary,
                    onTap: () => _openComments(context),
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: post.likes > 0 ? '${post.likes}' : '',
                    color:
                        isLiked ? AppColors.danger : AppColors.textSecondary,
                    onTap: () =>
                        state.toggleLike(post.postId, userPrefs.userId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text('This post will be permanently deleted. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseService.deletePost(post.postId);
    }
  }

  Future<void> _toggleStar() async {
    await FirebaseService.updatePost(
        post.postId, {'isOfficial': !post.isOfficial});
  }

  void _toggleDictionary(BuildContext context) {
    _showDictConfigSheet(context);
  }

  void _showDictConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DictConfigSheet(post: post),
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<AppState>()),
          ChangeNotifierProvider.value(value: context.read<UserPrefs>()),
        ],
        child: CommentSheet(post: post),
      ),
    );
  }

  Future<void> _showReportDialog(
      BuildContext context, String userId) async {
    final already = await FirebaseService.hasReported(post.postId, userId);
    if (!context.mounted) return;
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You have already reported this post'),
        backgroundColor: AppColors.textSecondary,
      ));
      return;
    }
    ReportReason? selected;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Report this post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ReportReason.values
                .map((r) => RadioListTile<ReportReason>(
                      title: Text(r.label),
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setS(() => selected = v),
                      activeColor: AppColors.primary,
                      dense: true,
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white),
              onPressed: selected == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await FirebaseService.reportPost(
                          post.postId, userId, selected!.name);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                        content: Text('Reported. Thank you for your feedback.'),
                        backgroundColor: AppColors.textSecondary,
                      ));
                    },
              child: const Text('Report'),
            ),
          ],
        );
      }),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (role) {
      'admin' => (Icons.admin_panel_settings, AppColors.danger, '@admin'),
      'expert' => (Icons.verified, AppColors.primary, '@expert'),
      _ => (null, AppColors.textSecondary, '@farmer'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
        ],
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final Post post;
  const _Avatar({required this.post});

  @override
  Widget build(BuildContext context) {
    final isExpert = post.userRole == 'expert';
    return CircleAvatar(
      radius: 18,
      backgroundColor: isExpert ? AppColors.primary : AppColors.accent,
      child: Text(
        post.userName.isNotEmpty ? post.userName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;
  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    if (!url.startsWith('http')) {
      // Non-HTTP URLs (demo emoji strings, etc.) — skip rendering
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 120,
          color: const Color(0xFFF5F5F5),
          child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 120,
          color: const Color(0xFFF5F5F5),
          child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.modeActive,
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.primaryDark)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Dictionary config sheet (admin only) ────────────────────────────────────

class _DictConfigSheet extends StatefulWidget {
  final Post post;
  const _DictConfigSheet({required this.post});

  @override
  State<_DictConfigSheet> createState() => _DictConfigSheetState();
}

class _DictConfigSheetState extends State<_DictConfigSheet> {
  late bool _inDictionary;
  late TextEditingController _cropCtrl;
  late TextEditingController _catCtrl;
  late List<String> _tags;
  final _tagCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _inDictionary = widget.post.inDictionary;
    _cropCtrl = TextEditingController(text: widget.post.dictCrop);
    _catCtrl = TextEditingController(text: widget.post.dictCategory);
    _tags = List.from(widget.post.dictTags);
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _catCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseService.updatePost(widget.post.postId, {
      'inDictionary': _inDictionary,
      'dictCrop': _cropCtrl.text.trim(),
      'dictCategory': _catCtrl.text.trim(),
      'dictTags': _tags,
      'isOfficial': _inDictionary ? true : widget.post.isOfficial,
    });
    if (mounted) Navigator.of(context).pop();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() => _tags.add(t));
    }
    _tagCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          const Text('Dictionary Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Add to dictionary',
                    style: TextStyle(fontSize: 14)),
              ),
              Switch(
                value: _inDictionary,
                onChanged: (v) => setState(() => _inDictionary = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (_inDictionary) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cropCtrl,
              decoration: InputDecoration(
                labelText: 'Crop',
                hintText: 'e.g. Maize, Tomato',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _catCtrl,
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Pests & Diseases, Growing Guide',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text('Keywords / Tags',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._tags.map((t) => Chip(
                      label: Text(t,
                          style: const TextStyle(fontSize: 12)),
                      onDeleted: () => setState(() => _tags.remove(t)),
                      deleteIconColor: AppColors.textSecondary,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0),
                      backgroundColor: AppColors.modeActive,
                    )),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _tagCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Add tag…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
