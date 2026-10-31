import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'core/app_theme.dart';
import 'core/localization/app_locale_service.dart';
import 'web_url_strategy.dart';
import 'services/app_session_manager.dart';
import 'services/biometric_lock_service.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart';
import 'services/auth/startup_authenticator.dart';
import 'pages/biometric_unlock_page/biometric_unlock_page_widget.dart';
import 'pages/all_transactions/all_transactions_widget.dart';
import 'pages/dashboard/dashboard_widget.dart';
import 'admin/pages/admin_password_reset_page.dart';
import 'utils/merchant_qr_parser.dart';

Widget buildSafeErrorWidget(FlutterErrorDetails details) {
  debugPrint('Suppressing app error overlay: ${details.exception}');
  return const SizedBox.shrink();
}

void main() async {
  print('APP START');
  WidgetsFlutterBinding.ensureInitialized();

  // Load dotenv early to avoid NotInitializedError when Env is referenced.
  try {
    // isOptional: a missing or empty .env falls back to production defaults.
    await dotenv.load(isOptional: true);
    debugPrint('Environment loaded (.env optional)');
  } catch (e) {
    debugPrint('Could not load .env (it may be missing): $e');
  }

  // Global Flutter framework error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  ErrorWidget.builder =
      (FlutterErrorDetails details) => buildSafeErrorWidget(details);

  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Restoring the persisted secure login session...');
  await FFAppState().initializePersistedState();
  // Attempt to restore persisted session and perform a silent refresh before
  // the app is started so routing decisions can use restored auth state.
  await StartupAuthenticator().restoreSession();
  await FlutterFlowTheme.initialize();

  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString('language');
  final languageCode = FFAppState().isLoggedIn &&
          AppLocaleService.supportedLocales
              .map((locale) => locale.languageCode)
              .contains(savedLanguage)
      ? savedLanguage!
      : 'en';

  if (FFAppState().isLoggedIn &&
      FFAppState().refreshToken.isNotEmpty &&
      FFAppState().isUser) {
    Future.microtask(() {
      AppSessionManager().refreshAppData().catchError((e) {
        debugPrint('[Main] Initial app refresh failed: $e');
      });
    });
  }

  configureUrlStrategy();

  // Run the app inside a guarded zone to capture uncaught errors with stack traces
  runZonedGuarded(() {
    runApp(
      EasyLocalization(
        startLocale: Locale(languageCode),
        supportedLocales: AppLocaleService.supportedLocales,
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => FFAppState()),
          ],
          child: const MyApp(),
        ),
      ),
    );

    // These services are optional at launch. They must not prevent the first
    // frame when device permissions or the backend are unavailable.
    unawaited(_initializeOptionalServices());
  }, (error, stack) {
    // Print uncaught errors to console so they appear in the browser devtools
    // and in the terminal running `flutter run`.
    // Use debugPrint if available at runtime.
    try {
      // ignore: avoid_print
      print('Uncaught error: $error');
      // ignore: avoid_print
      print(stack.toString());
    } catch (_) {}
  });
}

Future<void> _initializeOptionalServices() async {
  try {
    await NotificationService.initialize();
  } catch (error, stack) {
    debugPrint('[Main] Notification initialization skipped: $error');
    debugPrintStack(stackTrace: stack);
  }

  try {
    await SocketService.initialize();
  } catch (error, stack) {
    debugPrint('[Main] Socket initialization skipped: $error');
    debugPrintStack(stackTrace: stack);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialLocation});

  final String? initialLocation;

  @override
  State<MyApp> createState() => _MyAppState();

  // =========================================
  // REQUIRED BY FLUTTERFLOW
  // =========================================
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late AppStateNotifier _appStateNotifier;

  late GoRouter _router;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _appLinkSubscription;
  String? _pendingPasswordResetCode;
  String? _activePasswordResetCode;
  Timer? _refreshTimer;

  ThemeMode _effectiveThemeMode(String currentLocation) {
    return FFAppState().themeMode;
  }

  void _handleThemeModeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // =========================================
  // ROUTE HELPERS
  // =========================================
  String getRoute([RouteMatch? routeMatch]) {
    final routeConfig = _router.routerDelegate.currentConfiguration;
    if (routeConfig.isEmpty) {
      return '';
    }

    final RouteMatch lastMatch = routeMatch ?? routeConfig.last;

    final RouteMatchList matchList =
        lastMatch is ImperativeRouteMatch ? lastMatch.matches : routeConfig;

    if (matchList.uri.path.isEmpty) {
      return '';
    }

    return matchList.uri.path;
  }

  List<String> getRouteStack() {
    final currentConfig = _router.routerDelegate.currentConfiguration;
    if (currentConfig.isEmpty) {
      return <String>[];
    }

    return currentConfig.matches.map((e) => getRoute(e)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    FFAppState().addListener(_handleThemeModeChanged);

    _router = createRouter(
      _appStateNotifier,
      initialLocation: widget.initialLocation,
    );
    _appLinks = AppLinks();
    _appLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingAppLink,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[APP LINKS] Could not receive incoming link: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    unawaited(_handleInitialAppLink());
    final currentLocation = getRoute();
    print('Current route before redirect = $currentLocation');
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    unawaited(_appLinkSubscription?.cancel());
    FFAppState().removeListener(_handleThemeModeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleInitialAppLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) _handleIncomingAppLink(initialLink);
    } catch (error, stackTrace) {
      debugPrint('[APP LINKS] Could not read initial link: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleIncomingAppLink(Uri uri) {
    if (uri.scheme == 'farm' && uri.host == 'farm.com' && uri.path == '/pay') {
      final encodedPayload = uri.queryParameters['qr'];
      try {
        final payload = encodedPayload != null && encodedPayload.isNotEmpty
            ? utf8.decode(
                base64Url.decode(base64Url.normalize(encodedPayload)),
              )
            : uri.queryParameters['qrPayload']?.trim();
        final merchantId = uri.queryParameters['merchantId']?.trim();
        final businessName = uri.queryParameters['businessName']?.trim();
        final merchant = payload == null || payload.isEmpty
            ? null
            : parseMerchantQrPayload(payload);
        final resolvedMerchantId = merchant?.merchantId ?? merchantId ?? '';
        final resolvedBusinessName =
            merchant?.businessName ?? businessName ?? 'Merchant';
        if (resolvedMerchantId.isEmpty) {
          debugPrint(
            '[APP LINKS] Merchant payment link is missing its merchant ID',
          );
          return;
        }
        _router.go(Uri(
          path: '/merchantPayment',
          queryParameters: {
            'merchantId': resolvedMerchantId,
            'businessName': resolvedBusinessName,
            'qrPayload': payload ?? '',
          },
        ).toString());
      } catch (error) {
        debugPrint('[APP LINKS] Invalid merchant payment link: $error');
      }
      return;
    }

    final continueUrl = uri.queryParameters['continueUrl'];
    final continueUri = continueUrl == null ? null : Uri.tryParse(continueUrl);
    final isPasswordResetContinuation =
        continueUri?.host == 'farmapp-e2145.firebaseapp.com' &&
            continueUri?.path == '/admin-reset-password';
    final isPasswordResetHost = uri.path == '/admin-reset-password' &&
        (uri.host == 'farmapp.africa' ||
            uri.host == 'farmapp-e2145.firebaseapp.com');
    final isFirebaseActionHost = uri.host == 'farmapp-e2145.firebaseapp.com' &&
        uri.path.startsWith('/__/auth/action') &&
        isPasswordResetContinuation;
    final code = uri.queryParameters['oobCode'];
    if (!(isPasswordResetHost || isFirebaseActionHost) ||
        uri.queryParameters['mode'] != 'resetPassword' ||
        code == null ||
        code.isEmpty ||
        code == _activePasswordResetCode) {
      return;
    }

    _pendingPasswordResetCode = code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingAdminReset();
    });
  }

  void _openPendingAdminReset() {
    final code = _pendingPasswordResetCode;
    final navigator = appNavigatorKey.currentState;
    if (code == null || navigator == null) return;

    _pendingPasswordResetCode = null;
    _activePasswordResetCode = code;
    unawaited(
      navigator
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ResetPasswordPage(oobCode: code),
            ),
          )
          .whenComplete(() => _activePasswordResetCode = null),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('[APP] Resumed - session preserved');
      _startPeriodicRefresh();
      _refreshAppState();
      _handleResumeLock();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      debugPrint('[APP] Backgrounded - session preserved');
      _refreshTimer?.cancel();
    }
  }

  Future<void> _handleResumeLock() async {
    if (!mounted) return;
    if (!FFAppState().isLoggedIn || !FFAppState().isBiometricAllowed) {
      return;
    }

    final lockService = BiometricLockService();
    if (lockService.isAuthenticating) {
      debugPrint(
          '[Main] Biometric auth already in progress; skipping resume lock check.');
      return;
    }

    final shouldLock = await lockService.shouldRequireUnlock();
    if (shouldLock && getRoute() != BiometricUnlockPageWidget.routePath) {
      print('Navigating to ${BiometricUnlockPageWidget.routePath}');
      print('Navigating to ${BiometricUnlockPageWidget.routePath}');
      _router.go(BiometricUnlockPageWidget.routePath);
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    if (!mounted ||
        !FFAppState().isLoggedIn ||
        FFAppState().accessToken.isEmpty ||
        !FFAppState().isUser) {
      return;
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted ||
          !FFAppState().isLoggedIn ||
          FFAppState().accessToken.isEmpty) {
        return;
      }
      unawaited(_refreshAppState());
    });
  }

  Future<void> _refreshAppState() async {
    if (!mounted || !FFAppState().isLoggedIn) {
      return;
    }

    try {
      await AppSessionManager().refreshAppData();
    } catch (e) {
      debugPrint('App resume coordinated refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingPasswordResetCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPendingAdminReset();
      });
    }
    final effectiveThemeMode = _effectiveThemeMode(getRoute());
    Locale locale = const Locale('en');
    Iterable<Locale> supportedLocales = const [Locale('en')];
    List<LocalizationsDelegate<dynamic>> localizationDelegates = const [];
    try {
      locale = context.locale;
      supportedLocales = context.supportedLocales;
      localizationDelegates = context.localizationDelegates;
    } catch (_) {}

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FARM',
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationDelegates,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: effectiveThemeMode,
      routerConfig: _router,
      builder: (context, child) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !kIsWeb) {
            debugPrint('[APP] Android back - preserving session');
            if (_router.routeInformationProvider.value.uri.path ==
                AllTransactionsWidget.routePath) {
              _router.go(DashboardWidget.routePath);
            } else {
              SystemNavigator.pop();
            }
          }
        },
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
