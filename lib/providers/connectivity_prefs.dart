import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ユーザーが選択したダウンロードモードを管理する
/// modes は 'text', 'manual', 'visual' の部分集合
class ConnectivityPrefs extends ChangeNotifier {
  static const _key = 'connectivity_modes';
  static const _keySetup = 'setup_done';

  /// デフォルト: テキスト + テキスト+画像
  static const Set<String> defaultModes = {'text', 'manual'};

  Set<String> _modes = defaultModes;
  bool _setupDone = false;

  Set<String> get modes => _modes;
  bool get setupDone => _setupDone;

  /// このモードが有効かどうか
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
    // 'text' は常に有効（必須）
    final m = {'text', ...modes};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, m.toList());
    await prefs.setBool(_keySetup, true);
    _modes = m;
    _setupDone = true;
    notifyListeners();
  }
}
