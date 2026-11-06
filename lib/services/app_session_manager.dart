import 'dart:async';
import 'package:flutter/foundation.dart';
import '/app_state.dart';
import '/utils/personal_activity.dart';
import '/backend/services/api_service.dart';
import '/services/auth/refresh_manager.dart';

class AppSessionManager {
  static final AppSessionManager _instance = AppSessionManager._internal();
  factory AppSessionManager() => _instance;
  AppSessionManager._internal();

  bool _refreshInProgress = false;
  Completer<void>? _refreshCompleter;
  Future<void>? _sharedRefreshFuture;
  bool _sharedRefreshUsesForcedAuth = false;
  final Map<String, bool> _endpointInProgress = {};

  String _timeStamp() => DateTime.now().toIso8601String();

  Future<void> refreshAppData({bool forceAuthRefresh = false}) async {
    if (!FFAppState().isLoggedIn) {
      debugPrint('[AppSessionManager][${_timeStamp()}] Skipping refresh, user is not logged in.');
      return;
    }

    if (_sharedRefreshFuture != null) {
      debugPrint('[AppSessionManager][${_timeStamp()}] Reusing an existing app refresh.');
      final sharedFuture = _sharedRefreshFuture!;
      final sharedRefreshUsesForcedAuth = _sharedRefreshUsesForcedAuth;
      await sharedFuture;
      if (forceAuthRefresh && !sharedRefreshUsesForcedAuth) {
        await refreshAppData(forceAuthRefresh: true);
      }
      return;
    }

    final future = _refreshAppDataInternal(
      forceAuthRefresh: forceAuthRefresh,
    );
    _sharedRefreshFuture = future;
    _sharedRefreshUsesForcedAuth = forceAuthRefresh;
    try {
      await future;
    } finally {
      if (identical(_sharedRefreshFuture, future)) {
        _sharedRefreshFuture = null;
        _sharedRefreshUsesForcedAuth = false;
      }
    }
  }

  Future<void> refreshAfterTransaction() async {
    if (!FFAppState().isLoggedIn) {
      return;
    }

    try {
      final response = await ApiService.getTransactions(
        page: 1,
        limit: 5,
        timeoutSeconds: 4,
      );
      FFAppState().recentTransactions = _extractList(response)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(isPersonalActivity)
          .toList();
    } catch (error) {
      debugPrint('[AppSessionManager] Transaction refresh failed: $error');
    }
  }

  Future<void> _refreshAppDataInternal({
    required bool forceAuthRefresh,
  }) async {
    if (_refreshInProgress) {
      debugPrint('[AppSessionManager][${_timeStamp()}] Refresh already in progress. Waiting for completion.');
      return _refreshCompleter?.future ?? Future.value();
    }

    _refreshInProgress = true;
    _refreshCompleter = Completer<void>();
    final start = DateTime.now();
    debugPrint('[AppSessionManager][${start.toIso8601String()}] Starting coordinated app refresh.');

    // Helper to avoid duplicate endpoint fetches
    Future<Map<String, dynamic>?> _safeFetch(
      String key,
      Future<Map<String, dynamic>> Function() fetcher, {
      int timeoutSeconds = 5,
      bool background = false,
      int retries = 1,
    }) async {
      if (_endpointInProgress[key] == true) {
        debugPrint('[AppSessionManager] Skipping duplicate fetch: $key');
        return null;
      }
      _endpointInProgress[key] = true;
      try {
        final start = DateTime.now();
        Map<String, dynamic> res = await fetcher().timeout(Duration(seconds: timeoutSeconds));
        final dur = DateTime.now().difference(start);
        debugPrint('[AppSessionManager] Fetched $key in ${dur.inMilliseconds}ms');
        return res;
      } catch (e) {
        debugPrint('[AppSessionManager] $key fetch error: $e');
        final isRateLimited = e is ApiServiceException && e.statusCode == 429;
        if (!background && retries > 0 && !isRateLimited) {
          await Future.delayed(const Duration(milliseconds: 300));
          try {
            final retryRes = await fetcher().timeout(Duration(seconds: timeoutSeconds));
            return retryRes;
          } catch (e2) {
            debugPrint('[AppSessionManager] $key retry failed: $e2');
          }
        }
        return null;
      } finally {
        _endpointInProgress.remove(key);
      }
    }

    try {
      // Force token rotation on app resume; routine refreshes only renew tokens
      // when they are close to expiry.
      try {
        final refreshed = await RefreshManager()
            .refreshIfNeeded(force: forceAuthRefresh);
        debugPrint(
            '[AppSessionManager] refreshIfNeeded(force: $forceAuthRefresh) completed: $refreshed');
      } catch (e) {
        debugPrint(
            '[AppSessionManager] refreshIfNeeded(force: $forceAuthRefresh) failed: $e');
      }

      // 2) Use cached values if available to avoid UI placeholders
      final cachedProfile = ApiService.getCached('/users/me');
      final cachedWallet = ApiService.getCached('/wallet');
      if ((cachedProfile != null && cachedProfile.isNotEmpty) ||
          (cachedWallet != null && cachedWallet.isNotEmpty)) {
        FFAppState().batchUpdate(() {
          if (cachedProfile != null && cachedProfile.isNotEmpty) {
            final profileData = _extractData(cachedProfile);
            if (profileData.isNotEmpty) {
              FFAppState().userId = profileData['id']?.toString() ?? FFAppState().userId;
              FFAppState().firstName = profileData['first_name']?.toString() ?? FFAppState().firstName;
              FFAppState().userName = profileData['username']?.toString() ?? FFAppState().userName;
              FFAppState().phone = profileData['phone']?.toString() ?? FFAppState().phone;
              FFAppState().email = profileData['email']?.toString() ?? FFAppState().email;
              FFAppState().kycStatus = profileData['kyc_status']?.toString() ?? FFAppState().kycStatus;
              FFAppState().emailVerified = profileData['email_verified'] == true;
              if (profileData['profile_image'] != null) {
                FFAppState().profileImageUrl = profileData['profile_image']?.toString() ?? FFAppState().profileImageUrl;
              }
            }
          }

          if (cachedWallet != null && cachedWallet.isNotEmpty) {
            final walletData = _extractData(cachedWallet);
            if (walletData.isNotEmpty) {
              final walletBalance = double.tryParse(
                    (walletData['available_balance'] ?? walletData['balance'])
                            ?.toString() ??
                        '',
                  ) ??
                  FFAppState().walletBalance;
              final kesEquivalent = double.tryParse(walletData['kes_equivalent']?.toString() ?? '') ?? FFAppState().kesEquivalent;
              FFAppState().walletBalance = walletBalance;
              FFAppState().kesEquivalent = kesEquivalent;
            }
          }
        });
        debugPrint('[AppSessionManager] Applied cached profile/wallet to state');
      }

      // 3) Critical fetches concurrently: profile + wallet
      final criticalStart = DateTime.now();
      final profileFuture = _safeFetch('/users/me', () => ApiService.getProfile(timeoutSeconds: 2), timeoutSeconds: 2);
      final walletFuture = _safeFetch('/wallet', () => ApiService.getWallet(timeoutSeconds: 2), timeoutSeconds: 2);

      final results = await Future.wait([profileFuture, walletFuture], eagerError: false);
      final profileResp = results[0];
      final walletResp = results[1];

      FFAppState().batchUpdate(() {
        if (profileResp != null && profileResp.isNotEmpty) {
          final profileData = _extractData(profileResp);
          if (profileData.isNotEmpty) {
            FFAppState().userId = profileData['id']?.toString() ?? FFAppState().userId;
            FFAppState().firstName = profileData['first_name']?.toString() ?? FFAppState().firstName;
            FFAppState().userName = profileData['username']?.toString() ?? FFAppState().userName;
            FFAppState().phone = profileData['phone']?.toString() ?? FFAppState().phone;
            FFAppState().email = profileData['email']?.toString() ?? FFAppState().email;
            FFAppState().kycStatus = profileData['kyc_status']?.toString() ?? FFAppState().kycStatus;
            FFAppState().emailVerified = profileData['email_verified'] == true;
            FFAppState().role = profileData['role']?.toString() ?? FFAppState().role;
            if (profileData['profile_image'] != null) {
              FFAppState().profileImageUrl = profileData['profile_image']?.toString() ?? FFAppState().profileImageUrl;
            }

          }
        }

        if (walletResp != null && walletResp.isNotEmpty) {
          final walletData = _extractData(walletResp);
          if (walletData.isNotEmpty) {
            final walletBalance = double.tryParse(
                  (walletData['available_balance'] ?? walletData['balance'])
                          ?.toString() ??
                      '',
                ) ??
                FFAppState().walletBalance;
            final kesEquivalent = double.tryParse(walletData['kes_equivalent']?.toString() ?? '') ?? FFAppState().kesEquivalent;
            FFAppState().walletBalance = walletBalance;
            FFAppState().kesEquivalent = kesEquivalent;
          }
        }
      });

      final criticalDur = DateTime.now().difference(criticalStart).inMilliseconds;
      debugPrint('[AppSessionManager] Critical fetches done in ${criticalDur}ms');
      if (criticalDur > 1000) {
        debugPrint('[AppSessionManager] SLOW_CRITICAL_FETCH total=${criticalDur}ms');
      }

      // 4) Background fetches (do not block dashboard)
      void _spawnBackground(String key, Future<Map<String, dynamic>?> Function() fetch) {
        fetch().then((res) {
          if (res == null) return;
          try {
            if (key == 'transactions') {
              final items = _extractList(res);
              FFAppState().recentTransactions = items
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .where(isPersonalActivity)
                  .toList();
            } else if (key == 'notifications') {
              final items = _extractList(res);
              final unreadCount = items.where((item) {
                final read = item['read'] is bool
                    ? item['read'] as bool
                    : item['is_read'] is bool
                        ? item['is_read'] as bool
                        : item['isRead'] is bool
                            ? item['isRead'] as bool
                            : false;
                return !read;
              }).length;
              FFAppState().unreadNotificationCount = unreadCount;
            } else if (key == 'escrows') {
              // optionally store escrows in FFAppState if a field exists in future
            } else if (key == 'investments') {
              // optionally store investments in FFAppState if available
            }
          } catch (e) {
            debugPrint('[AppSessionManager] Background apply failed for $key: $e');
          }
        }).catchError((e) {
          debugPrint('[AppSessionManager] Background $key failed: $e');
        });
      }

      // Launch background fetches without awaiting
      _spawnBackground('transactions', () => _safeFetch('/wallet/transactions?page=1&limit=5', () => ApiService.getTransactions(page: 1, limit: 5, timeoutSeconds: 4), timeoutSeconds: 4, background: true));
      _spawnBackground('notifications', () => _safeFetch('/notifications', () => ApiService.getNotifications(timeoutSeconds: 4), timeoutSeconds: 4, background: true));
      _spawnBackground('escrows', () => _safeFetch('/escrow', () => ApiService.getEscrows(), timeoutSeconds: 5, background: true));
      _spawnBackground('investments', () => _safeFetch('/investments/my', () => ApiService.getMyInvestments(), timeoutSeconds: 5, background: true));

      debugPrint('[AppSessionManager][${_timeStamp()}] Global app state updated and UI notified.');
      _refreshCompleter?.complete();
    } catch (e, stackTrace) {
      debugPrint('[AppSessionManager][${_timeStamp()}] App refresh failed: $e');
      _refreshCompleter?.completeError(e, stackTrace);
      rethrow;
    } finally {
      _refreshInProgress = false;
      _refreshCompleter = null;
    }
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> _fetchWithLock(
    String key,
    Future<Map<String, dynamic>> Function() fetcher, {
    int timeoutSeconds = 5,
  }) async {
    if (_endpointInProgress[key] == true) {
      debugPrint('[AppSessionManager] _fetchWithLock skipping duplicate: $key');
      return null;
    }
    _endpointInProgress[key] = true;
    try {
      final start = DateTime.now();
      final res = await fetcher().timeout(Duration(seconds: timeoutSeconds));
      debugPrint('[AppSessionManager] _fetchWithLock $key in ${DateTime.now().difference(start).inMilliseconds}ms');
      return res;
    } catch (e) {
      debugPrint('[AppSessionManager] _fetchWithLock error $key: $e');
      return null;
    } finally {
      _endpointInProgress.remove(key);
    }
  }

  /// Force synchronous refresh of critical and near-critical data.
  /// This waits for profile, wallet and transactions and applies them to state.
  Future<void> syncNow({
    int authTimeoutSeconds = 3,
    int profileTimeoutSeconds = 5,
    int walletTimeoutSeconds = 7,
    int transactionsTimeoutSeconds = 6,
    bool forceAuthRefresh = false,
  }) async {
    if (!FFAppState().isLoggedIn) {
      debugPrint('[AppSessionManager] syncNow skipped because user is not logged in.');
      return;
    }

    if (_sharedRefreshFuture != null) {
      debugPrint('[AppSessionManager] syncNow reusing the existing app refresh.');
      final sharedFuture = _sharedRefreshFuture!;
      final sharedRefreshUsesForcedAuth = _sharedRefreshUsesForcedAuth;
      await sharedFuture;
      if (forceAuthRefresh && !sharedRefreshUsesForcedAuth) {
        await syncNow(
          authTimeoutSeconds: authTimeoutSeconds,
          profileTimeoutSeconds: profileTimeoutSeconds,
          walletTimeoutSeconds: walletTimeoutSeconds,
          transactionsTimeoutSeconds: transactionsTimeoutSeconds,
          forceAuthRefresh: true,
        );
      }
      return;
    }

    final future = _syncNowInternal(
      authTimeoutSeconds: authTimeoutSeconds,
      profileTimeoutSeconds: profileTimeoutSeconds,
      walletTimeoutSeconds: walletTimeoutSeconds,
      transactionsTimeoutSeconds: transactionsTimeoutSeconds,
      forceAuthRefresh: forceAuthRefresh,
    );
    _sharedRefreshFuture = future;
    _sharedRefreshUsesForcedAuth = forceAuthRefresh;
    try {
      await future;
    } finally {
      if (identical(_sharedRefreshFuture, future)) {
        _sharedRefreshFuture = null;
        _sharedRefreshUsesForcedAuth = false;
      }
    }
  }

  Future<void> _syncNowInternal({
    int authTimeoutSeconds = 3,
    int profileTimeoutSeconds = 5,
    int walletTimeoutSeconds = 7,
    int transactionsTimeoutSeconds = 6,
    required bool forceAuthRefresh,
  }) async {
    debugPrint('[AppSessionManager] syncNow starting. authTokenPresent=${FFAppState().accessToken.isNotEmpty}, refreshTokenPresent=${FFAppState().refreshToken.isNotEmpty}');

    // Force token rotation only when requested by an app-resume refresh.
    try {
      final refreshed = await RefreshManager()
          .refreshIfNeeded(force: forceAuthRefresh);
      debugPrint(
          '[AppSessionManager] syncNow refreshIfNeeded(force: $forceAuthRefresh) completed: $refreshed');
    } catch (e) {
      debugPrint(
          '[AppSessionManager] syncNow refreshIfNeeded(force: $forceAuthRefresh) failed: $e');
    }

    // 2) Fetch profile, wallet, transactions in parallel
    final profileF = _fetchWithLock(
      '/users/me',
      () => ApiService.getProfile(timeoutSeconds: profileTimeoutSeconds),
      timeoutSeconds: profileTimeoutSeconds,
    );
    final walletF = _fetchWithLock(
      '/wallet',
      () => ApiService.getWallet(timeoutSeconds: walletTimeoutSeconds),
      timeoutSeconds: walletTimeoutSeconds,
    );
    final txF = _fetchWithLock(
      '/wallet/transactions?page=1&limit=5',
      () => ApiService.getTransactions(page: 1, limit: 5, timeoutSeconds: transactionsTimeoutSeconds),
      timeoutSeconds: transactionsTimeoutSeconds,
    );

    final results = await Future.wait([profileF, walletF, txF], eagerError: false);
    final profileRes = results[0];
    final walletRes = results[1];
    final txRes = results[2];

    debugPrint('[AppSessionManager] syncNow fetch results profile=${profileRes != null} wallet=${walletRes != null} tx=${txRes != null}');

    if (txRes != null && txRes.isNotEmpty) {
      final txItems = _extractList(txRes);
      debugPrint('[AppSessionManager] syncNow transaction count=${txItems.length}');
    }

    if (walletRes != null && walletRes.isNotEmpty) {
      final walletData = _extractData(walletRes);
      debugPrint('[AppSessionManager] syncNow wallet data keys=${walletData.keys.join(', ')}');
    }

    FFAppState().batchUpdate(() {
      if (profileRes != null && profileRes.isNotEmpty) {
        final profileData = _extractData(profileRes);
        if (profileData.isNotEmpty) {
          FFAppState().userId = profileData['id']?.toString() ?? FFAppState().userId;
          FFAppState().firstName = profileData['first_name']?.toString() ?? FFAppState().firstName;
          FFAppState().userName = profileData['username']?.toString() ?? FFAppState().userName;
          FFAppState().phone = profileData['phone']?.toString() ?? FFAppState().phone;
          FFAppState().email = profileData['email']?.toString() ?? FFAppState().email;
          FFAppState().kycStatus = profileData['kyc_status']?.toString() ?? FFAppState().kycStatus;
          FFAppState().emailVerified = profileData['email_verified'] == true;
          FFAppState().role = profileData['role']?.toString() ?? FFAppState().role;
          if (profileData['profile_image'] != null) {
            FFAppState().profileImageUrl = profileData['profile_image']?.toString() ?? FFAppState().profileImageUrl;
          }
        }
      }

      if (walletRes != null && walletRes.isNotEmpty) {
        final walletData = _extractData(walletRes);
        if (walletData.isNotEmpty) {
          final walletBalance = double.tryParse(
                (walletData['available_balance'] ?? walletData['balance'])
                        ?.toString() ??
                    '',
              ) ??
              FFAppState().walletBalance;
          final kesEquivalent = double.tryParse(walletData['kes_equivalent']?.toString() ?? '') ?? FFAppState().kesEquivalent;
          FFAppState().walletBalance = walletBalance;
          FFAppState().kesEquivalent = kesEquivalent;
        }
      }

      if (txRes != null && txRes.isNotEmpty) {
        final txItems = _extractList(txRes);
        FFAppState().recentTransactions = txItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(isPersonalActivity)
            .toList();
      }
    });

    debugPrint('[AppSessionManager] syncNow completed. walletBalance=${FFAppState().walletBalance}, recentTransactions=${FFAppState().recentTransactions.length}');
  }
}
