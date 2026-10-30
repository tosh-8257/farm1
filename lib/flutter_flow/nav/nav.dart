import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/pages/change_pin_page/change_pin_page_widget.dart';
import '/pages/forgot_pin_page/forgot_pin_page_widget.dart';
import '/pages/splash_page.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/auth/route_guard_service.dart';
import '/pages/support/faq_page_widget.dart';
import '/pages/support/live_chat_page_widget.dart';
import '/pages/support/email_support_page_widget.dart';
import '/pages/notifications/user_notifications_page_widget.dart';
import '/pages/growth_tracking_page/growth_tracking_page_widget.dart';
import '/pages/settings/legal_document_page.dart';
import '/pages/payment_requests/request_money_widget.dart';
import '/admin/pages/admin_shell.dart';
import '/pages/payment_requests/incoming_requests_widget.dart';
import '/pages/public_pay_page.dart';
import '/pages/payment_success_page.dart';
import '/pages/receipts/receipt_pages.dart';
import '/index.dart';
import '/pages/business/business_onboarding_page.dart';
import '/pages/business/business_status_page.dart';
import '/pages/business/ops/pay_business_page.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String? _merchantPaymentLocationFromAppLink(GoRouterState state) {
  if (state.uri.path != '/pay') return null;

  final query = state.uri.queryParameters;
  final merchantId = query['merchantId']?.trim() ?? '';
  if (merchantId.isEmpty) return null;

  var qrPayload = query['qrPayload']?.trim() ?? '';
  final encodedPayload = query['qr']?.trim() ?? '';
  if (qrPayload.isEmpty && encodedPayload.isNotEmpty) {
    try {
      qrPayload = utf8.decode(
        base64Url.decode(base64Url.normalize(encodedPayload)),
      );
    } on FormatException {
      qrPayload = '';
    }
  }

  return Uri(
    path: '/merchantPayment',
    queryParameters: {
      'merchantId': merchantId,
      'businessName': query['businessName']?.trim().isNotEmpty == true
          ? query['businessName']!.trim()
          : 'Merchant',
      'qrPayload': qrPayload,
    },
  ).toString();
}

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  bool showSplashImage = true;

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(
  AppStateNotifier appStateNotifier, {
  String? initialLocation,
}) => GoRouter(
  initialLocation: initialLocation ?? OnboardingWidget.routePath,
  debugLogDiagnostics: true,
  refreshListenable: Listenable.merge([appStateNotifier, FFAppState()]),
  navigatorKey: appNavigatorKey,
  observers: [RouteLogger()],
  errorBuilder: (context, state) => LoginpageWidget(),
  redirect: (context, state) {
    final authState = FFAppState();
    final path = state.uri.path;
    if (path == '/pay/success') return null;
    final appPaymentLocation = _merchantPaymentLocationFromAppLink(state);
    if (appPaymentLocation != null) return appPaymentLocation;
    if (path.startsWith('/pay/')) return null;
    if (path == '/merchantPayment' &&
        authState.authStartupState == AuthStartupState.initializing) {
      return null;
    }
    final publicRoute = RouteGuardService().isPublicRoute(path);

    if (authState.authStartupState == AuthStartupState.initializing) {
      return path == OnboardingWidget.routePath || path == '/splash'
          ? null
          : OnboardingWidget.routePath;
    }

    if (authState.loginPreferencesPending &&
        (path == '/login' ||
            path == '/loginpage' ||
            path == '/otp' ||
            path == '/otppage')) {
      return null;
    }

    final role = authState.role.toLowerCase();
    final isLegalDocumentRoute =
        path == LegalDocumentPageWidget.privacyPolicyRoutePath ||
        path == LegalDocumentPageWidget.termsRoutePath;
    if (authState.isLoggedIn &&
        ((publicRoute && !isLegalDocumentRoute) ||
            path == OnboardingWidget.routePath)) {
      if (role == 'super_admin') return SuperadminDashboardPage.routePath;
      if (role == 'admin') return '/admin';
      return DashboardWidget.routePath;
    }

    if (!authState.isLoggedIn || authState.accessToken.isEmpty) {
      if (authState.isLoggedIn && authState.refreshToken.isNotEmpty) {
        return null;
      }
      if (path == '/merchantPayment') {
        authState.pendingMerchantPaymentRoute = state.uri.toString();
      }
      return publicRoute ? null : LoginpageWidget.routePath;
    }

    if (path.startsWith('/superadmin') && role != 'super_admin') {
      return role == 'admin' ? '/admin' : DashboardWidget.routePath;
    }
    if (path.startsWith('/admin') && role != 'admin' && role != 'super_admin') {
      return DashboardWidget.routePath;
    }
    if (role == 'super_admin' && path == DashboardWidget.routePath) {
      return SuperadminDashboardPage.routePath;
    }
    if (role == 'admin' && path == DashboardWidget.routePath) {
      return '/admin';
    }
    return null;
  },
  routes: [
    FFRoute(
      name: 'PaymentSuccess',
      path: '/pay/success',
      builder: (context, params) {
        final queryParameters = params.state.uri.queryParameters;
        final reference =
            [
                  'farm_reference',
                  'reference',
                  'trxref',
                  'tx_ref',
                  'transaction_reference',
                  'transactionId',
                  'transaction_id',
                  'payment_reference',
                  'paymentReference',
                  'payment_id',
                  'paymentId',
                  'checkout_id',
                  'checkoutId',
                  'merchant_reference',
                  'invoice_id',
                  'provider_reference',
                  'provider_transaction_id',
                  'provider_payment_id',
                  'provider_checkout_id',
                  'providerReference',
                  'id',
                ]
                .map((key) => queryParameters[key])
                .whereType<String>()
                .map((value) => value.trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        return PaymentSuccessPage(
          reference: reference.isEmpty ? null : reference,
        );
      },
    ),
    FFRoute(
      name: 'MerchantAppPaymentLink',
      path: '/pay',
      builder: (context, params) {
        final queryParameters = params.state.uri.queryParameters;
        return MerchantPaymentWidget(
          merchantId: queryParameters['merchantId'] ?? '',
          businessName: queryParameters['businessName'] ?? 'Merchant',
          qrPayload:
              queryParameters['qrPayload'] ?? queryParameters['qr'] ?? '',
        );
      },
    ),
    FFRoute(
      name: 'LegacyMerchantCheckoutRedirect',
      path: '/merchant-payment',
      builder: (context, params) {
        final queryParameters = params.state.uri.queryParameters;
        final reference =
            [
                  'farm_reference',
                  'reference',
                  'trxref',
                  'tx_ref',
                  'transaction_reference',
                  'transaction_id',
                  'payment_reference',
                  'provider_reference',
                  'provider_transaction_id',
                  'id',
                ]
                .map((key) => queryParameters[key])
                .whereType<String>()
                .map((value) => value.trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        if (reference.isNotEmpty) {
          return PaymentSuccessPage(reference: reference);
        }
        return LegacyMerchantQrRedirectPage(qrPayload: queryParameters['qr']);
      },
    ),
    FFRoute(
      name: 'PublicPay',
      path: '/pay/:merchantId',
      builder: (context, params) => PublicPayPage(
        merchantId: params.getParam('merchantId', ParamType.String) ?? '',
      ),
    ),
    FFRoute(
      name: SplashPage.routeName,
      path: SplashPage.routePath,
      builder: (context, _) => const SplashPage(),
    ),
    FFRoute(
      name: '_initialize',
      path: '/',
      builder: (context, _) => const OnboardingWidget(),
    ),
    FFRoute(
      name: OnboardingWidget.routeName,
      path: OnboardingWidget.routePath,
      builder: (context, params) => const OnboardingWidget(),
    ),
    FFRoute(
      name: DashboardWidget.routeName,
      path: DashboardWidget.routePath,
      builder: (context, params) => const DashboardWidget(),
    ),
    FFRoute(
      name: GrowthTrackingPageWidget.routeName,
      path: GrowthTrackingPageWidget.routePath,
      builder: (context, params) => const GrowthTrackingPageWidget(),
    ),
    FFRoute(
      name: SendReceiveWidget.routeName,
      path: SendReceiveWidget.routePath,
      builder: (context, params) => const SendReceiveWidget(),
    ),
    FFRoute(
      name: KycpageWidget.routeName,
      path: KycpageWidget.routePath,
      builder: (context, params) => KycpageWidget(
        startDiditVerification:
            params.state.uri.queryParameters['startDidit'] == 'true',
      ),
    ),
    FFRoute(
      name: QRScannerWidget.routeName,
      path: QRScannerWidget.routePath,
      builder: (context, params) => const QRScannerWidget(),
    ),
    FFRoute(
      name: EscrowHubWidget.routeName,
      path: EscrowHubWidget.routePath,
      builder: (context, params) => const EscrowHubWidget(),
    ),
    FFRoute(
      name: InvestmentMarketplaceWidget.routeName,
      path: InvestmentMarketplaceWidget.routePath,
      builder: (context, params) => const InvestmentMarketplaceWidget(),
    ),
    FFRoute(
      name: 'FaqPage',
      path: '/faq',
      builder: (context, params) => const FaqPageWidget(),
    ),
    FFRoute(
      name: 'LiveChatPage',
      path: '/chat',
      builder: (context, params) => const LiveChatPageWidget(),
    ),
    FFRoute(
      name: 'EmailSupportPage',
      path: '/email-support',
      builder: (context, params) => const EmailSupportPageWidget(),
    ),
    FFRoute(
      name: ProjectDetailsWidget.routeName,
      path: ProjectDetailsWidget.routePath,
      builder: (context, params) => ProjectDetailsWidget(
        projectId: params.getParam('projectId', ParamType.String) ?? '',
      ),
    ),
    FFRoute(
      name: BusinessOnboardingPage.routeName,
      path: BusinessOnboardingPage.routePath,
      builder: (context, params) => const BusinessOnboardingPage(),
    ),
    FFRoute(
      name: BusinessStatusPage.routeName,
      path: BusinessStatusPage.routePath,
      builder: (context, params) => const BusinessStatusPage(),
    ),
    FFRoute(
      name: PayBusinessPage.routeName,
      path: PayBusinessPage.routePath,
      builder: (context, params) =>
          PayBusinessPage(initialCode: params.getParam('code', ParamType.String)),
    ),
    FFRoute(
      name: MerchantDashboardWidget.routeName,
      path: MerchantDashboardWidget.routePath,
      builder: (context, params) => const MerchantDashboardWidget(),
    ),
    FFRoute(
      name: 'MerchantPayment',
      path: '/merchantPayment',
      builder: (context, params) => MerchantPaymentWidget(
        merchantId: params.getParam('merchantId', ParamType.String) ?? '',
        businessName: params.getParam('businessName', ParamType.String) ?? '',
        qrPayload: params.getParam('qrPayload', ParamType.String) ?? '',
      ),
    ),
    FFRoute(
      name: 'MerchantSales',
      path: '/merchantSales',
      builder: (context, params) => const MerchantSalesWidget(),
    ),
    FFRoute(
      name: 'ReceiptHistory',
      path: '/receipts',
      builder: (context, params) => const ReceiptHistoryPage(),
    ),
    FFRoute(
      name: 'ReceiptDetails',
      path: '/receipts/:receiptId',
      builder: (context, params) => ReceiptDetailsPage(
        receiptId: params.getParam('receiptId', ParamType.String) ?? '',
      ),
    ),
    FFRoute(
      name: RequestMoneyWidget.routeName,
      path: '/request-money',
      builder: (context, params) => const RequestMoneyWidget(),
    ),
    FFRoute(
      name: IncomingRequestsWidget.routeName,
      path: '/incoming-requests',
      builder: (context, params) => const IncomingRequestsWidget(),
    ),
    FFRoute(
      name: MoneyRequestApprovalPage.routeName,
      path: MoneyRequestApprovalPage.routePath,
      builder: (context, params) => MoneyRequestApprovalPage(
        requestId: params.getParam('requestId', ParamType.String) ?? '',
      ),
    ),
    FFRoute(
      name: AllTransactionsWidget.routeName,
      path: AllTransactionsWidget.routePath,
      builder: (context, params) => const AllTransactionsWidget(),
    ),
    FFRoute(
      name: ProfileSettingsWidget.routeName,
      path: ProfileSettingsWidget.routePath,
      builder: (context, params) => const ProfileSettingsWidget(),
    ),
    FFRoute(
      name: LoginpageWidget.routeName,
      path: LoginpageWidget.routePath,
      builder: (context, params) => LoginpageWidget(),
    ),
    FFRoute(
      name: OtppageWidget.routeName,
      path: OtppageWidget.routePath,
      builder: (context, params) => OtppageWidget(
        pendingLoginId:
            params.getParam('pendingLoginId', ParamType.String) ?? '',
        phone: params.getParam('phone', ParamType.String) ?? '',
        countryCode: params.getParam('countryCode', ParamType.String),
      ),
    ),
    FFRoute(
      name: 'AdminShell',
      path: '/admin',
      builder: (context, params) => const AdminShell(),
    ),
    FFRoute(
      name: RegisterpageWidget.routeName,
      path: RegisterpageWidget.routePath,
      builder: (context, params) => const RegisterpageWidget(),
    ),
    FFRoute(
      name: BiometricUnlockPageWidget.routeName,
      path: BiometricUnlockPageWidget.routePath,
      builder: (context, params) => const BiometricUnlockPageWidget(),
    ),
    FFRoute(
      name: DepositpageWidget.routeName,
      path: DepositpageWidget.routePath,
      builder: (context, params) => const DepositpageWidget(),
    ),
    FFRoute(
      name: WithdrawpageWidget.routeName,
      path: WithdrawpageWidget.routePath,
      builder: (context, params) => const WithdrawpageWidget(),
    ),
    FFRoute(
      name: ForgotPasswordPageWidget.routeName,
      path: ForgotPasswordPageWidget.routePath,
      builder: (context, params) => const ForgotPasswordPageWidget(),
    ),
    FFRoute(
      name: PinSetupPageWidget.routeName,
      path: PinSetupPageWidget.routePath,
      builder: (context, params) => const PinSetupPageWidget(),
    ),
    FFRoute(
      name: ChangePinPageWidget.routeName,
      path: ChangePinPageWidget.routePath,
      builder: (context, params) => const ChangePinPageWidget(),
    ),
    FFRoute(
      name: ForgotPinPageWidget.routeName,
      path: ForgotPinPageWidget.routePath,
      builder: (context, params) => const ForgotPinPageWidget(),
    ),
    FFRoute(
      name: NotificationSettingsPageWidget.routeName,
      path: NotificationSettingsPageWidget.routePath,
      builder: (context, params) => const NotificationSettingsPageWidget(),
    ),
    FFRoute(
      name: UserNotificationsPageWidget.routeName,
      path: UserNotificationsPageWidget.routePath,
      builder: (context, params) => const UserNotificationsPageWidget(),
    ),
    FFRoute(
      name: LanguageSettingsPageWidget.routeName,
      path: LanguageSettingsPageWidget.routePath,
      builder: (context, params) => const LanguageSettingsPageWidget(),
    ),
    FFRoute(
      name: LegalDocumentPageWidget.privacyPolicyRouteName,
      path: LegalDocumentPageWidget.privacyPolicyRoutePath,
      builder: (context, params) => const LegalDocumentPageWidget(
        title: 'Privacy Policy',
        assetPath: 'assets/docs/privacy_policy.md',
      ),
    ),
    FFRoute(
      name: LegalDocumentPageWidget.termsRouteName,
      path: LegalDocumentPageWidget.termsRoutePath,
      builder: (context, params) => const LegalDocumentPageWidget(
        title: 'Terms of Service',
        assetPath: 'assets/docs/terms_and_conditions.md',
      ),
    ),
    FFRoute(
      name: SupportHelpCenterPageWidget.routeName,
      path: SupportHelpCenterPageWidget.routePath,
      builder: (context, params) => const SupportHelpCenterPageWidget(),
    ),
    FFRoute(
      name: DeleteAccountPageWidget.routeName,
      path: DeleteAccountPageWidget.routePath,
      builder: (context, params) => const DeleteAccountPageWidget(),
    ),
    FFRoute(
      name: SuperadminDashboardPage.routeName,
      path: SuperadminDashboardPage.routePath,
      builder: (context, params) => const SuperadminDashboardPage(),
    ),
    FFRoute(
      name: UserManagementPage.routeName,
      path: UserManagementPage.routePath,
      builder: (context, params) => const UserManagementPage(),
    ),
    FFRoute(
      name: AddAdminPage.routeName,
      path: AddAdminPage.routePath,
      builder: (context, params) => const AddAdminPage(),
    ),
    FFRoute(
      name: SuperadminWalletPage.routeName,
      path: SuperadminWalletPage.routePath,
      builder: (context, params) => const SuperadminWalletPage(),
    ),
    FFRoute(
      name: SuperadminPinSetupPage.routeName,
      path: SuperadminPinSetupPage.routePath,
      builder: (context, params) => const SuperadminPinSetupPage(),
    ),
    FFRoute(
      name: SuperadminChangePinPage.routeName,
      path: SuperadminChangePinPage.routePath,
      builder: (context, params) => const SuperadminChangePinPage(),
    ),
  ].map((r) => r.toRoute(appStateNotifier)).toList(),
);

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
    entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)),
  );
}

extension NavigationExtensions on BuildContext {
  void safePop() {
    debugPrint('[NAV] back pressed');
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      // If running on web, navigate to root. On mobile, if we're already
      // at a logical app root (dashboard or admin shells), exit the
      // activity so Android/OS shows the launcher instead of pushing an
      // empty route which can produce a blank Flutter surface on some
      // devices/configurations.
      try {
        if (!kIsWeb) {
          final loc = GoRouter.of(
            appNavigatorKey.currentContext!,
          ).getCurrentLocation();
          // If we're on a top-level dashboard/admin route, exit the app.
          if (loc.startsWith(DashboardWidget.routePath) ||
              loc.startsWith('/admin') ||
              loc.startsWith(SuperadminDashboardPage.routePath)) {
            SystemNavigator.pop();
            return;
          }
        }
      } catch (_) {}
      go('/');
    }
  }
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class RouteLogger extends NavigatorObserver {
  void _logRouteChange(
    String event,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    final routeName =
        route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';
    final previousName =
        previousRoute?.settings.name ??
        previousRoute?.runtimeType.toString() ??
        'none';
    final role = FFAppState().role;
    final accessTokenLength = FFAppState().accessToken.length;
    final refreshTokenLength = FFAppState().refreshToken.length;
    final sessionExists =
        FFAppState().accessToken.isNotEmpty ||
        FFAppState().refreshToken.isNotEmpty;
    print(
      'ROUTE CHANGE: event=$event route=$routeName previous=$previousName role=$role accessTokenLength=$accessTokenLength refreshTokenLength=$refreshTokenLength sessionExists=$sessionExists',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange('didPush', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRouteChange('didReplace', newRoute, oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange('didPop', previousRoute, route);
  }
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
    state.allParams.entries.where(isAsyncParam).map((param) async {
      final doc = await asyncParams[param.key]!(
        param.value,
      ).onError((_, __) => null);
      if (doc != null) {
        futureParamValues[param.key] = doc;
        return true;
      }
      return false;
    }),
  ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(String paramName, ParamType type, {bool isList = false}) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(param, type, isList);
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
    name: name,
    path: path,
    pageBuilder: (context, state) {
      fixStatusBarOniOS16AndBelow(context);
      final ffParams = FFParameters(state, asyncParams);
      final page = ffParams.hasFutures
          ? FutureBuilder(
              future: ffParams.completeFutures(),
              builder: (context, _) => builder(context, ffParams),
            )
          : builder(context, ffParams);
      final child = page;

      final transitionInfo = state.transitionInfo;
      return transitionInfo.hasTransition
          ? CustomTransitionPage(
              key: state.pageKey,
              name: state.name,
              child: child,
              transitionDuration: transitionInfo.duration,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      PageTransition(
                        type: transitionInfo.transitionType,
                        duration: transitionInfo.duration,
                        reverseDuration: transitionInfo.duration,
                        alignment: transitionInfo.alignment,
                        child: child,
                      ).buildTransitions(
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ),
            )
          : MaterialPage(key: state.pageKey, name: state.name, child: child);
    },
    routes: routes,
  );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() =>
      const TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) =>
      Provider.value(value: RootPageContext(true, errorRoute), child: child);
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
