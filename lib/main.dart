import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/post_create_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/map_screen.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
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
      home: const MainShell(),
    );
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Dict'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Post'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
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
                        ? 'デモデータを9件 Firestore に追加しました'
                        : 'すでにデータが存在するためスキップしました'),
                    backgroundColor: seeded ? AppColors.primary : Colors.grey,
                    duration: const Duration(seconds: 3),
                  ));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'seed',
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('デモデータを投入'),
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
      4 => _buildProfilePlaceholder(),
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
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<AppState>(),
          child: const PostCreateScreen(),
        ),
      ),
    );
  }

  Widget _buildProfilePlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text('Profile coming soon', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}
