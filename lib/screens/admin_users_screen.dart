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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await FirebaseService.fetchUsers();
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
    // Toggle between farmer and admin (expert also available)
    final newRole = showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Set role'),
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
    _load();
  }

  Widget _roleOption(BuildContext ctx, String role, String current) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, role),
      child: Row(
        children: [
          Icon(
            role == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
            color: role == current ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            role,
            style: TextStyle(
              fontWeight: role == current ? FontWeight.bold : FontWeight.normal,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? const Center(
                      child: Text('No registered users yet.',
                          style:
                              TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final user = _users[i];
                        final uid = user['uid'] as String;
                        final name = (user['userName'] ?? '') as String;
                        final email = (user['email'] ?? '') as String;
                        final role = (user['role'] ?? 'farmer') as String;
                        final isMe = uid == myUid;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _roleColor(role).withOpacity(0.15),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
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
                                color: _roleColor(role).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        _roleColor(role).withOpacity(0.3)),
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
    );
  }
}
