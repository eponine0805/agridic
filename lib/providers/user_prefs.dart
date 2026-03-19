import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserPrefs extends ChangeNotifier {
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';

  String _userId = '';
  String _userName = '';

  String get userId => _userId;
  String get userName => _userName.isEmpty ? '農家' : _userName;

  UserPrefs() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyUserId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_keyUserId, id);
    }
    _userId = id;
    _userName = prefs.getString(_keyUserName) ?? '';
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    _userName = name;
    notifyListeners();
  }
}
