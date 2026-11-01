import 'dart:async';
import '/services/account_context.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_theme.dart';
import 'backend/services/api_service.dart';
import 'services/auth/session_store_service.dart';
import 'services/secure_storage_service.dart';
import 'services/offline_cache.dart';

enum AuthStartupState { initializing, authenticated, unauthenticated }

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  AuthStartupState _authStartupState = AuthStartupState.initializing;
  AuthStartupState get authStartupState => _authStartupState;
  bool get isAuthInitializing =>
      _authStartupState == AuthStartupState.initializing;

  bool _loginPreferencesPending = false;
  bool get loginPreferencesPending => _loginPreferencesPending;
  set loginPreferencesPending(bool value) {
    if (_loginPreferencesPending == value) return;
    _loginPreferencesPending = value;
    notifyListeners();
  }

  String _pendingMerchantPaymentRoute = '';
  String get pendingMerchantPaymentRoute => _pendingMerchantPaymentRoute;
  set pendingMerchantPaymentRoute(String value) {
    _pendingMerchantPaymentRoute = value;
  }

  void setAuthStartupState(AuthStartupState value) {
    if (_authStartupState == value) return;
    _authStartupState = value;
    notifyListeners();
  }

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future<void> initializePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedStoredRole =
        (await AuthSessionStore.readActiveRole() ?? '').toLowerCase();

    final adminSession = await AuthSessionStore.readAdminSession();
    final superAdminSession = await AuthSessionStore.readSuperAdminSession();
    final userSession = await AuthSessionStore.readUserSession();
    final secureAccessToken = await SecureStorageService.readAccessToken() ?? '';
    final secureRefreshToken =
        await SecureStorageService.readRefreshToken() ?? '';
    final secureUserId = await SecureStorageService.readUserId() ?? '';
    final secureIsLoggedIn = await SecureStorageService.readIsLoggedIn();

    if (normalizedStoredRole == 'admin' && adminSession != null) {
      _accessToken = adminSession.accessToken;
      _refreshToken = adminSession.refreshToken;
      _userId = adminSession.userId;
      _role = adminSession.role;
      _isLoggedIn = adminSession.accessToken.isNotEmpty ||
          adminSession.refreshToken.isNotEmpty;
    } else if (normalizedStoredRole == 'super_admin' &&
        superAdminSession != null) {
      _accessToken = superAdminSession.accessToken;
      _refreshToken = superAdminSession.refreshToken;
      _userId = superAdminSession.userId;
      _role = superAdminSession.role;
      _isLoggedIn = superAdminSession.accessToken.isNotEmpty ||
          superAdminSession.refreshToken.isNotEmpty;
    } else if (normalizedStoredRole == 'user' && userSession != null) {
      _accessToken = userSession.accessToken;
      _refreshToken = userSession.refreshToken;
      _userId = userSession.userId;
      _role = userSession.role;
      _isLoggedIn = userSession.accessToken.isNotEmpty ||
          userSession.refreshToken.isNotEmpty;
    } else if (normalizedStoredRole.isNotEmpty &&
        (secureAccessToken.isNotEmpty ||
            secureRefreshToken.isNotEmpty ||
            secureIsLoggedIn)) {
      _accessToken = secureAccessToken;
      _refreshToken = secureRefreshToken;
      _userId = secureUserId;
      _role = normalizedStoredRole;
      _isLoggedIn =
          secureAccessToken.isNotEmpty ||
              secureRefreshToken.isNotEmpty ||
              secureIsLoggedIn;
    } else {
      _accessToken = '';
      _refreshToken = '';
      _userId = '';
      _role = '';
      _isLoggedIn = false;
    }

    if (_isLoggedIn && _role.isNotEmpty) {
      await AuthSessionStore.saveRoleSession(
        role: _role,
        accessToken: _accessToken,
        refreshToken: _refreshToken,
        userId: _userId,
      );
    }

    _firstName = prefs.getString('firstName') ?? '';
    _userName = prefs.getString('userName') ?? '';
    _phone = prefs.getString('phone') ?? '';
    _email = prefs.getString('email') ?? '';
    _kycStatus = prefs.getString('kycStatus') ?? '';
    // Authentication is restored only from the selected role session. Legacy
    // SharedPreferences auth keys must never resurrect a different session.
    _biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
    _hasPin = prefs.getBool('hasPin') ?? false;
    _pushNotifications = prefs.getBool('pushNotifications') ?? true;
    _emailNotifications = prefs.getBool('emailNotifications') ?? false;
    _inAppNotifications = prefs.getBool('inAppNotifications') ?? true;
    _smsNotifications = prefs.getBool('smsNotifications') ?? false;
    _notificationSoundEnabled =
        prefs.getBool('notificationSoundEnabled') ?? true;
    _notificationVibrationEnabled =
        prefs.getBool('notificationVibrationEnabled') ?? true;
    _walletBalance = prefs.getDouble('walletBalance') ?? 0.0;
    _kesEquivalent = prefs.getDouble('kesEquivalent') ?? 0.0;
    _profileImageUrl = prefs.getString('profileImageUrl') ?? '';
    _unreadNotificationCount = prefs.getInt('unreadNotificationCount') ?? 0;
    if (prefs.containsKey('biometricLockTimeoutSeconds')) {
      _biometricLockTimeoutSeconds =
          prefs.getInt('biometricLockTimeoutSeconds') ?? 600;
    } else if (prefs.containsKey('biometricLockTimeoutMinutes')) {
      _biometricLockTimeoutSeconds =
          (prefs.getInt('biometricLockTimeoutMinutes') ?? 10) * 60;
    } else {
      _biometricLockTimeoutSeconds = 600;
    }
    final storedBiometricVerified = prefs.getString('biometric_last_verified');
    if (storedBiometricVerified != null) {
      _biometricLastVerified = DateTime.tryParse(storedBiometricVerified);
    } else {
      _biometricLastVerified =
          await SecureStorageService.readBiometricLastVerified();
    }

    // Theme is a device preference and is independent of the active session.
    // Never fall back to the operating-system theme: only an explicit user
    // choice may enable dark mode.
    final themeModeString =
        prefs.getString('themeMode') ?? prefs.getString('__theme_mode__');
    final legacyDarkMode = prefs.getBool('__theme_mode__');
    _themeMode = themeModeString == ThemeMode.dark.name ||
            (themeModeString == null && legacyDarkMode == true)
        ? ThemeMode.dark
        : ThemeMode.light;
    if (_role.isEmpty || !_isLoggedIn) {
      _biometricsEnabled = false;
    }

    // Diagnostic auth restore log
    debugPrint(
        '[AUTH STARTUP] Restored role=$_role accessTokenPresent=${_accessToken.isNotEmpty} refreshTokenPresent=${_refreshToken.isNotEmpty} authenticated=$_isLoggedIn');
  }

  bool _suspendNotifications = false;

  void _notifyListeners() {
    if (!_suspendNotifications) {
      notifyListeners();
    }
  }

  void update(VoidCallback callback) {
    callback();
    _notifyListeners();
  }

  void batchUpdate(VoidCallback callback) {
    _suspendNotifications = true;
    callback();
    _suspendNotifications = false;
    notifyListeners();
  }

  String _accessToken = '';
  String get accessToken => _accessToken;
  set accessToken(String value) {
    if (_accessToken == value) return;
    _accessToken = value;
    notifyListeners();
    unawaited(SecureStorageService.writeAccessToken(value));
  }

  String get authToken => _accessToken;

  Future<String> getActiveAccessToken() async {
    if (_accessToken.isNotEmpty) {
      return _accessToken;
    }

    final secureToken = await SecureStorageService.readAccessToken();
    if (secureToken != null && secureToken.isNotEmpty) {
      _accessToken = secureToken;
      _isLoggedIn = true;
      notifyListeners();
      return _accessToken;
    }

    final normalizedRole = _role.toLowerCase();
    final persistedSession =
        await AuthSessionStore.readRoleSession(normalizedRole);
    final persistedToken = persistedSession?.accessToken ?? '';
    if (persistedToken.isNotEmpty) {
      // Lazily restore in-memory token from persisted role session without
      // clearing other persisted storage. Do not assume session is invalid —
      // token will be validated by RefreshManager when needed.
      _accessToken = persistedToken;
      _refreshToken = persistedSession?.refreshToken ?? _refreshToken;
      _userId = persistedSession?.userId ?? _userId;
      _role = persistedSession?.role ?? _role;
      _isLoggedIn = persistedToken.isNotEmpty;
      notifyListeners();
    }
    return _accessToken;
  }

  String _refreshToken = '';
  String get refreshToken => _refreshToken;
  set refreshToken(String value) {
    if (_refreshToken == value) return;
    _refreshToken = value;
    notifyListeners();
    unawaited(SecureStorageService.writeRefreshToken(value));
  }

  String _userId = '';
  String get userId => _userId;
  set userId(String value) {
    if (_userId == value) return;
    _userId = value;
    notifyListeners();
    unawaited(SecureStorageService.writeUserId(value));
    // Offline screen cache is per user.
    unawaited(OfflineCache.ensureScope(value));
  }

  String _firstName = '';
  String get firstName => _firstName;
  set firstName(String value) {
    if (_firstName == value) return;
    _firstName = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('firstName', value),
    );
  }

  String _userName = '';
  String get userName => _userName;
  set userName(String value) {
    if (_userName == value) return;
    _userName = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('userName', value),
    );
  }

  String _phone = '';
  String get phone => _phone;
  set phone(String value) {
    if (_phone == value) return;
    _phone = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('phone', value),
    );
  }

  String _email = '';
  String get email => _email;
  set email(String value) {
    if (_email == value) return;
    _email = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('email', value),
    );
  }

  String _kycStatus = '';
  String get kycStatus => _kycStatus;
  set kycStatus(String value) {
    if (_kycStatus == value) return;
    _kycStatus = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('kycStatus', value),
    );
  }

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;
  set isLoggedIn(bool value) {
    if (_isLoggedIn == value) return;
    _isLoggedIn = value;
    notifyListeners();
    unawaited(SecureStorageService.writeIsLoggedIn(value));
  }

  bool _biometricsEnabled = false;
  bool get biometricsEnabled => _biometricsEnabled;
  set biometricsEnabled(bool value) {
    if (_biometricsEnabled == value) return;
    _biometricsEnabled = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('biometricsEnabled', value),
    );
  }

  bool _hasPin = false;
  bool get hasPin => _hasPin;
  set hasPin(bool value) {
    if (_hasPin == value) return;
    _hasPin = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('hasPin', value),
    );
  }

  DateTime? _biometricLastVerified;
  DateTime? get biometricLastVerified => _biometricLastVerified;
  set biometricLastVerified(DateTime? value) {
    if (_biometricLastVerified == value) return;
    _biometricLastVerified = value;
    notifyListeners();
    if (value == null) {
      SecureStorageService.deleteBiometricLastVerified();
      SharedPreferences.getInstance().then(
        (prefs) => prefs.remove('biometric_last_verified'),
      );
    } else {
      SecureStorageService.writeBiometricLastVerified(value.toIso8601String());
      SharedPreferences.getInstance().then(
        (prefs) =>
            prefs.setString('biometric_last_verified', value.toIso8601String()),
      );
    }
  }

  int _biometricLockTimeoutSeconds = 600;
  int get biometricLockTimeoutSeconds => _biometricLockTimeoutSeconds;
  set biometricLockTimeoutSeconds(int value) {
    if (_biometricLockTimeoutSeconds == value) return;
    _biometricLockTimeoutSeconds = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt('biometricLockTimeoutSeconds', value),
    );
  }

  bool _notificationSoundEnabled = true;
  bool get notificationSoundEnabled => _notificationSoundEnabled;
  set notificationSoundEnabled(bool value) {
    if (_notificationSoundEnabled == value) return;
    _notificationSoundEnabled = value;
    _notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('notificationSoundEnabled', value),
    );
  }

  bool _notificationVibrationEnabled = true;
  bool get notificationVibrationEnabled => _notificationVibrationEnabled;
  set notificationVibrationEnabled(bool value) {
    if (_notificationVibrationEnabled == value) return;
    _notificationVibrationEnabled = value;
    _notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('notificationVibrationEnabled', value),
    );
  }

  bool _pushNotifications = true;
  bool get pushNotifications => _pushNotifications;
  set pushNotifications(bool value) {
    if (_pushNotifications == value) return;
    _pushNotifications = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('pushNotifications', value),
    );
  }

  bool _emailNotifications = false;
  bool get emailNotifications => _emailNotifications;
  set emailNotifications(bool value) {
    if (_emailNotifications == value) return;
    _emailNotifications = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('emailNotifications', value),
    );
  }

  bool _inAppNotifications = true;
  bool get inAppNotifications => _inAppNotifications;
  set inAppNotifications(bool value) {
    if (_inAppNotifications == value) return;
    _inAppNotifications = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('inAppNotifications', value),
    );
  }

  bool _smsNotifications = false;
  bool get smsNotifications => _smsNotifications;
  set smsNotifications(bool value) {
    if (_smsNotifications == value) return;
    _smsNotifications = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('smsNotifications', value),
    );
  }

  bool _emailVerified = false;
  bool get emailVerified => _emailVerified;
  set emailVerified(bool value) {
    if (_emailVerified == value) return;
    _emailVerified = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('emailVerified', value),
    );
  }

  String _role = '';
  String get role => _role;
  set role(String value) {
    if (_role == value) return;
    _role = value;
    notifyListeners();
    unawaited(SecureStorageService.writeRole(value));
  }

  bool get isUser => _role.toLowerCase() == 'user';
  bool get isAdmin =>
      _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'super_admin';
  bool get isBiometricAllowed => isUser && _biometricsEnabled;

  double _walletBalance = 0.0;
  double get walletBalance => _walletBalance;
  set walletBalance(double value) {
    if (_walletBalance == value) return;
    _walletBalance = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setDouble('walletBalance', value),
    );
  }

  double _kesEquivalent = 0.0;
  double get kesEquivalent => _kesEquivalent;
  set kesEquivalent(double value) {
    if (_kesEquivalent == value) return;
    _kesEquivalent = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setDouble('kesEquivalent', value),
    );
  }

  String _profileImageUrl = '';
  String get profileImageUrl => _profileImageUrl;
  set profileImageUrl(String value) {
    if (_profileImageUrl == value) return;
    _profileImageUrl = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('profileImageUrl', value),
    );
  }

  int _unreadNotificationCount = 0;
  int get unreadNotificationCount => _unreadNotificationCount;
  set unreadNotificationCount(int value) {
    if (_unreadNotificationCount == value) return;
    _unreadNotificationCount = value;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt('unreadNotificationCount', value),
    );
  }

  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> get recentTransactions => _recentTransactions;
  set recentTransactions(List<Map<String, dynamic>> value) {
    if (_recentTransactions == value) return;
    _recentTransactions = value;
    notifyListeners();
    OfflineCache.write('recentTransactions', value);
  }

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    final selectedMode = value == ThemeMode.system ? ThemeMode.light : value;
    if (_themeMode == selectedMode) return;
    _themeMode = selectedMode;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('themeMode', selectedMode.name),
    );
    FlutterFlowTheme.saveThemeMode(selectedMode);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
  }

  /// Fills in-memory screen data from the offline cache (after
  /// [OfflineCache.load]) so the first frame shows the last known values.
  void hydrateFromOfflineCache() {
    final tx = OfflineCache.read('recentTransactions');
    if (tx is List && _recentTransactions.isEmpty) {
      _recentTransactions = tx
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  Future<void> clearAuthCredentials([String? reason]) async {
    final msg = '[FFAppState] clearAuthCredentials called' +
        (reason != null ? ' reason=$reason' : '');
    debugPrint(msg);
    debugPrint(StackTrace.current.toString());
    // Next sign-in always starts in the Personal account.
    unawaited(AccountContext.instance.reset());
    accessToken = '';
    refreshToken = '';
    userId = '';
    firstName = '';
    userName = '';
    phone = '';
    kycStatus = '';
    isLoggedIn = false;
    loginPreferencesPending = false;
    setAuthStartupState(AuthStartupState.unauthenticated);
    biometricsEnabled = false;
    hasPin = false;
    role = '';
    walletBalance = 0;
    kesEquivalent = 0;
    _recentTransactions = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('walletBalance');
    await prefs.remove('kesEquivalent');
    // Stale-while-revalidate screen cache belongs to this user only.
    await OfflineCache.clear();
    await prefs.remove('firstName');
    await prefs.remove('userName');
    await prefs.remove('phone');
    await prefs.remove('kycStatus');
    await prefs.remove('biometricsEnabled');
    await prefs.remove('lastAuthenticatedRoute');
    await prefs.remove('biometric_last_verified');
    await SecureStorageService.clearBiometricData();
    await AuthSessionStore.clearAllSessions();
    // Cached API responses can contain another user's profile or role.
    // Discard them together with the authenticated session.
    try {
      ApiService.invalidateCache();
    } catch (_) {}
  }

  Future<void> clearRoleSession(String role) async {
    print('CLEAR SESSION CALLED');
    print(StackTrace.current);
    final normalizedRole = role.toLowerCase();
    if (normalizedRole == 'admin') {
      await AuthSessionStore.clearAdminSession();
    } else if (normalizedRole == 'super_admin') {
      await AuthSessionStore.clearSuperAdminSession();
    } else {
      await AuthSessionStore.clearUserSession();
    }
  }
}
