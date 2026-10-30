import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which account the user is currently operating as.
enum AccountMode { personal, business }

/// Holds the Personal/Business selection for the session and persists it so it
/// survives app restarts. The backend remains the source of truth for whether
/// a business account is actually active; the UI only switches the view.
class AccountContext extends ChangeNotifier {
  AccountContext._();
  static final AccountContext instance = AccountContext._();

  static const _prefsKey = 'accountMode';

  AccountMode _mode = AccountMode.personal;
  bool _loaded = false;

  AccountMode get mode => _mode;
  bool get isBusiness => _mode == AccountMode.business;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_prefsKey) == 'business'
        ? AccountMode.business
        : AccountMode.personal;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AccountMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  /// Called on logout so the next user always starts in Personal.
  Future<void> reset() async {
    _mode = AccountMode.personal;
    _loaded = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
