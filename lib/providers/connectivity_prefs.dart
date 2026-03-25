import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's selected download modes.
/// modes is a subset of 'text', 'manual', 'visual'
class ConnectivityPrefs extends ChangeNotifier {
  static const _key = 'connectivity_modes';
  static const _keySetup = 'setup_done';

  /// Default: text + text+images
  static const Set<String> defaultModes = {'text', 'manual'};

  Set<String> _modes = defaultModes;
  bool _setupDone = false;

  Set<String> get modes => _modes;
  bool get setupDone => _setupDone;

  /// Returns true if the given mode is enabled.
  bool isEnabled(String mode) => _modes.contains(mode);

  ConnectivityPrefs() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _setupDone = prefs.getBool(_keySetup) ?? false;
    final saved = prefs.getStringList(_key);
    if (saved != null && saved.isNotEmpty) {
      _modes = saved.toSet();
    } else {
      _modes = Set.from(defaultModes);
    }
    notifyListeners();
  }

  Future<void> saveModes(Set<String> modes) async {
    // 'text' is always enabled (required)
    final m = {'text', ...modes};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, m.toList());
    await prefs.setBool(_keySetup, true);
    _modes = m;
    _setupDone = true;
    notifyListeners();
  }
}
