import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  bool _searched = false; // 一度も検索していない状態を区別
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'キーワードを入力してください';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final users = await FirebaseService.searchUsers(query);
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _setRole(String uid, String currentRole) async {
    final newRole = showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('ロールを変更'),
        children: [
          _roleOption(ctx, 'farmer', currentRole),
          _roleOption(ctx, 'expert', currentRole),
          _roleOption(ctx, 'admin', currentRole),
        ],
      ),
    );
    final role = await newRole;
    if (role == null || role == currentRole) return;

    await FirebaseService.setUserRole(uid, role);
    _search(); // 変更後に再検索
  }

  Widget _roleOption(BuildContext ctx, String role, String current) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, role),
      child: Row(
        children: [
          Icon(
            role == current
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color:
                role == current ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            role,
            style: TextStyle(
              fontWeight:
                  role == current ? FontWeight.bold : FontWeight.normal,
              color: _roleColor(role),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
        'admin' => AppColors.danger,
        'expert' => AppColors.primary,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<UserPrefs>().userId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('User Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '名前またはメールで検索…',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.primary, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18,
                                  color: AppColors.textSecondary),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _users = [];
                                  _searched = false;
                                  _error = null;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('検索'),
                ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 12)),
            ),

          // 検索結果
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : !_searched
                    ? const Center(
                        child: Text(
                          '名前またはメールアドレスで検索してください',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              '"${_searchCtrl.text.trim()}" に一致するユーザーが見つかりません',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final user = _users[i];
                              final uid = user['uid'] as String;
                              final name =
                                  (user['userName'] ?? '') as String;
                              final email =
                                  (user['email'] ?? '') as String;
                              final role =
                                  (user['role'] ?? 'farmer') as String;
                              final isMe = uid == myUid;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _roleColor(role).withOpacity(0.15),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: _roleColor(role),
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name.isNotEmpty ? name : email,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    if (isMe)
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text('You',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.primary)),
                                      ),
                                  ],
                                ),
                                subtitle: Text(email,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                trailing: GestureDetector(
                                  onTap: () => _setRole(uid, role),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _roleColor(role)
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: _roleColor(role)
                                              .withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _roleColor(role)),
                                    ),
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 4),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
