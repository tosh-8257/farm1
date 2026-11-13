import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/app_state.dart';
import '/admin/services/admin_api_service.dart';
import '/core/config/supabase_config.dart';
import '/services/auth/refresh_manager.dart';
import 'session_store_service.dart';

/// Service to check and enforce route protection based on authentication status.
///
/// Requirements:
/// 1. Valid Supabase session must exist
/// 2. Valid Backend JWT (FARM JWT) must be stored in FFAppState
/// 3. Both must be present for protected routes
class RouteGuardService {
  static final RouteGuardService _instance = RouteGuardService._internal();

  factory RouteGuardService() {
    return _instance;
  }

  RouteGuardService._internal();

  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Check if user has a valid Supabase session.
  ///
  /// Returns true if:
  /// - Supabase has an active session
  /// - Session is not expired
  Future<bool> hasValidSupabaseSession() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session == null) {
        return false;
      }

      // Check if access token is still valid
      if (session.isExpired) {
        return false;
      }

      return true;
    } catch (e) {
      final message = e.toString();
      if (message.contains('LateInitializationError') ||
          message.contains('must initialize the supabase instance') ||
          message.contains('Not initialized')) {
        return false;
      }
      debugPrint('Error checking Supabase session: $e');
      return false;
    }
  }

  /// Check if user has a valid Backend JWT (FARM JWT).
  ///
  /// Returns true if FFAppState has a non-empty accessToken and the user is
  /// marked as logged in, or if there is a persisted backend token available.
  Future<bool> hasValidBackendJwt() async {
    final state = FFAppState();
    var role = state.role.toLowerCase();
    if (role.isEmpty) {
      role = (await AuthSessionStore.readActiveRole() ?? '').toLowerCase();
      if (role.isNotEmpty) state.role = role;
    }
    if (role.isEmpty) return false;

    var accessToken = state.accessToken;
    var refreshToken = state.refreshToken;
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      final persistedSession = await AuthSessionStore.readRoleSession(role);
      if (persistedSession != null) {
        if (accessToken.isEmpty && persistedSession.accessToken.isNotEmpty) {
          accessToken = persistedSession.accessToken;
          state.accessToken = accessToken;
        }
        if (refreshToken.isEmpty && persistedSession.refreshToken.isNotEmpty) {
          refreshToken = persistedSession.refreshToken;
          state.refreshToken = refreshToken;
        }
        if (state.userId.isEmpty && persistedSession.userId.isNotEmpty) {
          state.userId = persistedSession.userId;
        }
      }
    }

    if (accessToken.isNotEmpty && _isJwtValid(accessToken)) {
      state.isLoggedIn = true;
      return true;
    }

    if (refreshToken.isNotEmpty) {
      try {
        await RefreshManager().refreshIfNeeded(force: true);
      } catch (error) {
        debugPrint('[RouteGuardService] Silent token refresh failed: $error');
      }
    } else if (role == 'admin' || role == 'super_admin') {
      try {
        await AdminApiService.ensureValidSession(force: true);
      } catch (error) {
        debugPrint('[RouteGuardService] Admin session refresh failed: $error');
      }
    }

    // A revoked or expired session has already cleared local credentials.
    // A generic refresh rejection keeps them so biometric unlock still works
    // after the app is closed. A stale terminal flag must not discard a
    // session that now has tokens again.
    final signedOut = state.accessToken.isEmpty && state.refreshToken.isEmpty;
    if (signedOut &&
        (!state.isLoggedIn || RefreshManager().lastFailureWasTerminal)) {
      return false;
    }

    final hasLocalSession = state.isLoggedIn ||
        state.accessToken.isNotEmpty ||
        state.refreshToken.isNotEmpty;
    if (hasLocalSession) state.isLoggedIn = true;
    return hasLocalSession;
  }

  static bool _isJwtValid(String token) {
    final expiry = _getJwtExpiry(token);
    if (expiry == null) {
      return false;
    }
    return expiry.isAfter(DateTime.now().toUtc());
  }

  static DateTime? _getJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payloadMap['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is String) {
        final value = int.tryParse(exp);
        if (value != null) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
        }
      }
    } catch (e) {
      debugPrint('[RouteGuardService] Failed to parse JWT expiry: $e');
    }
    return null;
  }

  /// Check if the current session is authenticated for the active role.
  ///
  /// This is the primary check for route protection and startup auth checks.
  ///
  /// Returns true when:
  /// 1. A backend JWT exists in state
  /// 2. The active role is a user and the user is marked logged-in or has a
  ///    valid Supabase session
  /// 3. The active role is admin/super_admin and the backend JWT is present
  Future<bool> isUserAuthenticated() async {
    try {
      final state = FFAppState();
      final hasBackendJwt = await hasValidBackendJwt();
      final role = state.role.toLowerCase();
      final isLoggedInFlag = state.isLoggedIn;
      final hasSupabaseSession = await hasValidSupabaseSession();
      final isAdminRole = role == 'admin' || role == 'super_admin';

      final hasLocalCredentials = state.isLoggedIn ||
          state.accessToken.isNotEmpty ||
          state.refreshToken.isNotEmpty;
      if ((!hasBackendJwt && !hasLocalCredentials) || role.isEmpty) {
        return false;
      }

      if (isAdminRole) {
        return true;
      }

      return isLoggedInFlag || hasSupabaseSession;
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      return false;
    }
  }

  /// Check if a specific route requires authentication.
  ///
  /// Public routes (no auth required):
  /// - /splash
  /// - /
  /// - /onboarding
  /// - /login
  /// - /register
  /// - /forgot-password
  /// - /otp
  bool isPublicRoute(String path) {
    final publicPaths = [
      '/',
      '/splash',
      '/onboarding',
      '/login',
      '/loginpage',
      '/register',
      '/registerpage',
      '/forgot-password',
      '/forgotPasswordPage',
      '/reset-password',
      '/verify-email',
      '/otp',
      '/otppage',
      '/privacyPolicy',
      '/termsOfService',
    ];

    return path == '/' ||
        publicPaths
            .where((publicPath) => publicPath != '/')
            .any((publicPath) => path.startsWith(publicPath));
  }

  /// Verify authentication and handle redirect if needed.
  ///
  /// Used in GoRouter redirect callback.
  /// Returns the redirect path if auth is required and user is not authenticated,
  /// otherwise returns null (no redirect).
  Future<String?> verifyAndRedirect(
    BuildContext context,
    String currentPath,
  ) async {
    final role = FFAppState().role.toLowerCase();
    final loggedIn = FFAppState().isLoggedIn;
    final accessTokenLength = FFAppState().accessToken.length;
    final refreshTokenLength = FFAppState().refreshToken.length;
    final persistedSession = await AuthSessionStore.readRoleSession(role);
    final sessionExists = persistedSession != null &&
        (persistedSession.accessToken.isNotEmpty ||
            persistedSession.refreshToken.isNotEmpty);

    print('AUTH GUARD CHECK');
    print('Current route: $currentPath');
    print('Current role: $role');
    print('Access token length: $accessTokenLength');
    print('Refresh token length: $refreshTokenLength');
    print('Session exists: $sessionExists');

    // Public routes don't need protection
    if (isPublicRoute(currentPath)) {
      print('Reason for redirect: none (public route)');
      return null;
    }

    // Check if user is authenticated
    final isAuthenticated = await isUserAuthenticated();
    if (!isAuthenticated) {
      final reason = accessTokenLength == 0
          ? 'accessToken.isEmpty'
          : role.isEmpty
              ? 'role.isEmpty'
              : 'no valid auth session';

      debugPrint('[RouteGuardService] verifyAndRedirect NOT authenticated');
      debugPrint(
          '[RouteGuardService] role=$role loggedIn=$loggedIn currentPath=$currentPath');
      debugPrint('[RouteGuardService] redirect reason=$reason');
      if (sessionExists) return null;
      if (role == 'super_admin') {
        debugPrint('SUPER_ADMIN REDIRECTED TO LOGIN');
        debugPrint(StackTrace.current.toString());
      }
      // Do NOT clear persisted auth here — preserve tokens and let explicit
      // logout or genuine backend revocation handle clearing. Redirect to
      // login so the user can re-authenticate if desired.
      debugPrint(
          '[RouteGuardService] Not authenticated — redirecting to login (preserving persisted session)');
      return '/loginpage';
    }

    debugPrint(
        '[RouteGuardService] verifyAndRedirect authenticated role=$role currentPath=$currentPath');
    debugPrint(
        '[RouteGuardService] verifyAndRedirect state accessTokenLength=$accessTokenLength refreshTokenLength=$refreshTokenLength sessionExists=$sessionExists');
    return null;
  }
}
