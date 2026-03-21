import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/app_state.dart';
import 'providers/user_prefs.dart';
import 'screens/home_screen.dart';
import 'screens/post_create_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/map_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dict_download_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/user_posts_screen.dart';
import 'screens/notifications_screen.dart';
import 'utils/app_colors.dart';

/// バックグラウンド / 終了状態でのプッシュ通知受信ハンドラ
/// トップレベル関数でなければならない
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // システムが自動でトレイ通知を表示する。追加処理は不要。
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // バックグラウンドハンドラを登録
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserPrefs()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const AgridicApp(),
    ),
  );
}

class AgridicApp extends StatelessWidget {
  const AgridicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agridic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.outfitTextTheme(),
        useMaterial3: true,
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final userPrefs = context.read<UserPrefs>();

    // Firebase Auth のセッション復元が完了するまで待つ（固定遅延なし）
    // → 既ログイン済みの場合はログイン画面をスキップできる
    while (userPrefs.isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    // 1. Auth — require login
    if (!userPrefs.isLoggedIn) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: userPrefs,
          child: const LoginScreen(),
        ),
        fullscreenDialog: true,
      ));
      if (!mounted) return;
    }

    // 2. Dictionary first download
    if (context.read<UserPrefs>().isLoggedIn &&
        !context.read<UserPrefs>().firstDownloadDone) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<UserPrefs>(),
          child: const DictDownloadScreen(isFirstRun: true),
        ),
        fullscreenDialog: true,
      ));
      if (!mounted) return;
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final _homeScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // フォアグラウンド中にプッシュ通知が届いたら未読数をインクリメント + SnackBar 表示
    FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      // ストリームなしで未読バッジを更新
      context.read<UserPrefs>().incrementUnreadCount();
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      if (title.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(body.isNotEmpty ? '$title\n$body' : title),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '確認',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(
                        value: context.read<AppState>()),
                    ChangeNotifierProvider.value(
                        value: context.read<UserPrefs>()),
                  ],
                  child: const NotificationsScreen(),
                ),
              ),
            );
          },
        ),
      ));
    });
  }

  @override
  void dispose() {
    _homeScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: SafeArea(
        top: _selectedIndex != 0,
        child: _buildBody(),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: _openPostCreate,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.modeActive,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Dict'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Post'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(Icons.eco, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(
            'Agridic',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        // 通知ベルアイコン（UserPrefs のキャッシュ済み未読数を使用 — Firestore ストリーム不要）
        Consumer<UserPrefs>(
          builder: (context, userPrefs, _) {
            if (!userPrefs.isLoggedIn) return const SizedBox.shrink();
            final count = userPrefs.unreadCount;
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 24),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider.value(
                          value: context.read<AppState>()),
                      ChangeNotifierProvider.value(
                          value: context.read<UserPrefs>()),
                    ],
                    child: const NotificationsScreen(),
                  ),
                ),
              ),
            );
          },
        ),
        Consumer2<AppState, UserPrefs>(
          builder: (context, state, userPrefs, _) {
            return PopupMenuButton<String>(
              icon: state.isSeeding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                if (value == 'seed') {
                  final seeded = await state.seedDemoData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(seeded
                        ? 'Added 9 demo posts to Firestore'
                        : 'Data already exists — skipped'),
                    backgroundColor:
                        seeded ? AppColors.primary : Colors.grey,
                    duration: const Duration(seconds: 3),
                  ));
                } else if (value == 'force_seed') {
                  await state.forceSeedDemoData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('[Debug] Demo data loaded to Firestore'),
                    backgroundColor: AppColors.accent,
                    duration: Duration(seconds: 3),
                  ));
                }
              },
              itemBuilder: (_) => [
                if (userPrefs.isAdmin) ...[
                  const PopupMenuItem(
                    value: 'seed',
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Seed demo data (skip if exists)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'force_seed',
                    child: Row(
                      children: [
                        Icon(Icons.bug_report_outlined, size: 18, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text('[Debug] Force load demo data',
                            style: TextStyle(color: AppColors.accent)),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
      elevation: 2,
    );
  }

  Widget _buildBody() {
    return switch (_selectedIndex) {
      0 => HomeScreen(scrollController: _homeScrollCtrl),
      1 => const DictionaryScreen(),
      3 => const MapScreen(),
      4 => const _ProfileScreen(),
      _ => const HomeScreen(),
    };
  }

  void _onNavTap(int index) {
    if (index == 2) {
      _openPostCreate();
      return;
    }
    // ホームタブを既にホームにいる状態で押したらトップへスクロール
    if (index == 0 && _selectedIndex == 0) {
      if (_homeScrollCtrl.hasClients) {
        _homeScrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _openPostCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: context.read<AppState>()),
            ChangeNotifierProvider.value(value: context.read<UserPrefs>()),
          ],
          child: const PostCreateScreen(),
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  Future<void> _editProfile() async {
    final userPrefs = context.read<UserPrefs>();
    final nameCtrl = TextEditingController(text: userPrefs.userName);
    final bioCtrl = TextEditingController(text: userPrefs.userBio);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final nameErr = await userPrefs.updateDisplayName(nameCtrl.text);
      final bioErr = await userPrefs.updateBio(bioCtrl.text);
      if (!mounted) return;
      final err = nameErr ?? bioErr;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    nameCtrl.dispose();
    bioCtrl.dispose();
  }

  Color _roleColor(String role) => switch (role) {
        'admin' => AppColors.danger,
        'expert' => AppColors.primary,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final userPrefs = context.watch<UserPrefs>();
    final isAdmin = userPrefs.isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                userPrefs.userName.isNotEmpty
                    ? userPrefs.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              userPrefs.userName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
          Center(
            child: Text(
              userPrefs.userEmail,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _roleColor(userPrefs.userRole).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _roleColor(userPrefs.userRole).withOpacity(0.3)),
              ),
              child: Text(
                userPrefs.userRole.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _roleColor(userPrefs.userRole)),
              ),
            ),
          ),
          if (userPrefs.userBio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                userPrefs.userBio,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // My Posts button
          _SettingsTile(
            icon: Icons.article_outlined,
            label: 'My Posts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(
                        value: context.read<AppState>()),
                    ChangeNotifierProvider.value(
                        value: context.read<UserPrefs>()),
                  ],
                  child: UserPostsScreen(
                    userId: userPrefs.userId,
                    userName: userPrefs.userName,
                    isOwn: true,
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.menu_book_outlined,
            label: 'Re-download dictionary',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<UserPrefs>(),
                  child: const DictDownloadScreen(isFirstRun: false),
                ),
              ),
            ),
          ),
          // ── Admin Panel ──────────────────────────────
          if (isAdmin) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  const Text('Admin Panel',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.manage_accounts_outlined,
              label: 'Manage users',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<UserPrefs>(),
                    child: const AdminUsersScreen(),
                  ),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.campaign_outlined,
              label: 'Send notification to all',
              onTap: () async {
                final sent = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<UserPrefs>(),
                    child: const AdminBroadcastDialog(),
                  ),
                );
                if (sent == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Notification sent to all users'),
                    backgroundColor: AppColors.primary,
                  ));
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Sign out',
            labelColor: AppColors.danger,
            onTap: () async {
              await context.read<UserPrefs>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const _StartupRouter()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          size: 20,
          color: labelColor ?? AppColors.textSecondary),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, color: labelColor ?? AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right,
          size: 18, color: AppColors.textSecondary),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
