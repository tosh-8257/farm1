import 'dart:async';
import 'package:flutter/foundation.dart';
import '/core/config/env.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '/flutter_flow/flutter_flow_util.dart';
import '/backend/services/api_service.dart';
import '/services/app_session_manager.dart';

class SocketService {
  SocketService._();

  static final SocketService _instance = SocketService._();

  factory SocketService() => _instance;

  io.Socket? _socket;
  bool _initialized = false;
  String _identifiedToken = '';
  Timer? _refreshTimer;

  static Future<void> initialize() async {
    final service = SocketService();
    if (service._initialized) return;

    service._initialized = true;
    FFAppState().addListener(service._handleAuthStateChanged);
    service._connect();
  }

  void _handleAuthStateChanged() {
    final token = FFAppState().accessToken;
    if (token == _identifiedToken) return;

    final wasIdentified = _identifiedToken.isNotEmpty;
    _identifiedToken = token;

    if (wasIdentified) {
      _socket?.disconnect();
      _socket = null;
    }

    if (token.isEmpty) return;

    if (_socket == null) {
      _connect();
    } else if (_socket!.connected) {
      _identify();
    } else {
      _socket!.connect();
    }
  }

  void _connect() {
    final backendUrl = Env.backendUrl;

    final normalizedUrl =
        backendUrl.endsWith('/ws') ? backendUrl : '$backendUrl/ws';

    _socket = io.io(
      normalizedUrl,
      io.OptionBuilder()
          // Render may reset a direct WebSocket upgrade. Socket.IO can establish
          // the session over polling and upgrade to WebSocket when available.
          .setTransports(['polling', 'websocket'])
          .disableAutoConnect()
          .enableForceNewConnection()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .setTimeout(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] connected');
      _identify();
    });

    _socket!.onConnectError((error) {
      debugPrint(
          '[Socket] realtime connection unavailable; HTTP features remain available');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[Socket] disconnected: $reason');
    });

    _socket!.on('transaction:update', (data) {
      debugPrint('[Socket] transaction:update: $data');
      _scheduleAppRefresh();
    });

    _socket!.on('balance:update', (data) {
      debugPrint('[Socket] balance:update: $data');
      _applyBalanceUpdate(data);
      _scheduleAppRefresh();
    });

    _socket!.on('error', (data) {
      debugPrint('[Socket] server error: $data');
    });

    _socket!.connect();
  }

  void _applyBalanceUpdate(dynamic data) {
    final payload = data is Map ? data : null;
    final nestedPayload = payload?['data'];
    final rawBalance = payload?['balance'] ??
        payload?['available_balance'] ??
        (nestedPayload is Map
            ? nestedPayload['balance'] ?? nestedPayload['available_balance']
            : null);
    final balance = rawBalance is num
        ? rawBalance.toDouble()
        : double.tryParse(rawBalance?.toString() ?? '');

    if (balance == null || !balance.isFinite) {
      debugPrint('[Socket] ignored balance:update with invalid balance: $data');
      return;
    }

    ApiService.invalidateCache('/wallet');
    FFAppState().walletBalance = balance;
  }

  void _scheduleAppRefresh() {
    if (!FFAppState().isLoggedIn) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(AppSessionManager()
          .refreshAfterTransaction()
          .catchError((Object error) {
        debugPrint('[Socket] transaction refresh failed: $error');
      }));
    });
  }

  Future<void> _identify() async {
    final token = FFAppState().accessToken;
    if (token.isEmpty) {
      debugPrint('[Socket] no access token available yet');
      return;
    }

    _identifiedToken = token;
    _socket?.emit('identify', {'token': token});
    debugPrint('[Socket] identify sent');
  }

  void reconnect() {
    if (_socket == null) {
      _connect();
      return;
    }

    if (!_socket!.connected) {
      _socket!.connect();
      return;
    }

    _identify();
  }

  void dispose() {
    _refreshTimer?.cancel();
    FFAppState().removeListener(_handleAuthStateChanged);
    _socket?.disconnect();
    _socket = null;
    _identifiedToken = '';
    _initialized = false;
  }
}
