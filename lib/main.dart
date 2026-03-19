import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_state.dart';
import 'providers/user_prefs.dart';
import 'providers/connectivity_prefs.dart';
import 'screens/home_screen.dart';
import 'screens/post_create_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/map_screen.dart';
import 'screens/login_screen.dart';
import 'screens/connectivity_settings_screen.dart';
import 'screens/dict_download_screen.dart';
import 'screens/admin_users_screen.dart';
import 'services/firebase_service.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserPrefs()),
        ChangeNotifierProvider(create: (_) => ConnectivityPrefs()),
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
    // Wait a tick for UserPrefs to finish auth-state resolution
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final userPrefs = context.read<UserPrefs>();
    final connPrefs = context.read<ConnectivityPrefs>();

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

    // 2. Download settings (first run)
    if (!connPrefs.setupDone) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: connPrefs,
          child: const ConnectivitySettingsScreen(isFirstRun: true),
        ),
        fullscreenDialog: true,
      ));
      if (!mounted) return;
    }

    // 3. Dictionary first download
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
        Consumer<AppState>(
          builder: (context, state, _) {
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
                } else if (value == 'settings') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<ConnectivityPrefs>(),
                      child: const ConnectivitySettingsScreen(),
                    ),
                  ));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.signal_cellular_alt_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Download settings'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'seed',
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Seed demo data'),
                    ],
                  ),
                ),
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
      0 => const HomeScreen(),
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
  bool _claimingAdmin = false;

  Future<void> _claimAdmin() async {
    setState(() => _claimingAdmin = true);
    final userPrefs = context.read<UserPrefs>();
    final success = await FirebaseService.claimFirstAdmin(userPrefs.userId);
    if (!mounted) return;
    if (success) {
      // Reload role from Firestore
      await userPrefs.reloadRole();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Admin privileges granted to your account'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 3),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('An admin already exists. Ask them to grant you access.'),
        backgroundColor: AppColors.textSecondary,
        duration: Duration(seconds: 3),
      ));
    }
    setState(() => _claimingAdmin = false);
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
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.signal_cellular_alt_outlined,
            label: 'Download settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<ConnectivityPrefs>(),
                  child: const ConnectivitySettingsScreen(),
                ),
              ),
            ),
          ),
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
          if (isAdmin) ...[
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
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          // Claim first admin (only shown when not already admin)
          if (!isAdmin) ...[
            ListTile(
              leading: _claimingAdmin
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textSecondary))
                  : const Icon(Icons.shield_outlined,
                      size: 20, color: AppColors.textSecondary),
              title: const Text('Claim admin (first time only)',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              subtitle: const Text(
                  'Only works if no admin exists yet',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              contentPadding: EdgeInsets.zero,
              onTap: _claimingAdmin ? null : _claimAdmin,
            ),
            const SizedBox(height: 8),
          ],
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
