import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppRole { elder, admin }

class AppState extends ChangeNotifier {
  static const _roleKey = 'selected_role';
  static const _elderSetupDoneKey = 'elder_setup_done';

  AppRole? _role;
  AppRole? get role => _role;

  bool _elderSetupDone = false;
  bool get elderSetupDone => _elderSetupDone;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final v = prefs.getString(_roleKey);
    _role = switch (v) {
      'elder' => AppRole.elder,
      'admin' => AppRole.admin,
      _ => null,
    };

    _elderSetupDone = prefs.getBool(_elderSetupDoneKey) ?? false;

    notifyListeners();
  }

  Future<void> setRole(AppRole role) async {
    _role = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
    notifyListeners();
  }

  Future<void> setElderSetupDone(bool done) async {
    _elderSetupDone = done;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_elderSetupDoneKey, done);
    notifyListeners();
  }

  Future<void> clearRole() async {
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    notifyListeners();
  }
}
