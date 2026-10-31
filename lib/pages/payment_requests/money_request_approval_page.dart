import 'dart:async';

import 'package:flutter/material.dart';
import '/widgets/common/back_chevron.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Removed unused imports
import '/services/app_session_manager.dart';
import '/services/transaction_authorization_service.dart';
import '/utils/user_error_message.dart';

class MoneyRequestApprovalPage extends StatefulWidget {
  const MoneyRequestApprovalPage(
      {super.key, required this.requestId, this.compact = false});

  final String requestId;
  final bool compact;

  static const routeName = 'MoneyRequestApprovalPage';
  static const routePath = '/money-request-approval/:requestId';

  @override
  State<MoneyRequestApprovalPage> createState() =>
      _MoneyRequestApprovalPageState();
}

class _MoneyRequestApprovalPageState extends State<MoneyRequestApprovalPage> {
  late Future<Map<String, dynamic>> _future;
  Timer? _timer;
  Timer? _refreshTimer;
  int _secondsRemaining = 0;
  int _loadAttempts = 0;
  bool _processing = false;
  bool _completed = false;
  String? _statusMessage;
  String? _error;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _future = _loadRequest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadRequest() async {
    _loadAttempts = 0;
    while (_loadAttempts < 10) {
      try {
        _loadAttempts += 1;
        final data = await ApiService.request(
            method: 'GET', path: '/payment-requests/${widget.requestId}');
        final request = data['data'] as Map<String, dynamic>?;
        if (!mounted) return data;
        setState(() {
          _error = null;
          if (request != null) {
            _updateStatusFromRequest(request);
          }
        });
        _startCountdown(request?['expires_at']);
        _startRefreshLoop();
        return data;
      } catch (e) {
        _error = 'Unable to load request. Retrying... ($_loadAttempts/10)';
        if (_loadAttempts >= 10) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    throw Exception('Failed to load payment request');
  }

  void _updateStatusFromRequest(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase() ?? '';
    if (status == 'pending') {
      _completed = false;
      _isExpired = false;
      _statusMessage = null;
      return;
    }

    _completed = true;
    _isExpired = status == 'expired';
    _statusMessage = status == 'completed'
        ? 'Request paid'
        : status == 'accepted'
            ? 'Request approved'
            : status == 'rejected' || status == 'declined'
                ? 'Request declined'
                : status == 'cancelled'
                    ? 'Request cancelled'
                    : status == 'expired'
                        ? 'This payment request has expired.'
                        : 'Request status: ${request['status']}';
  }

  void _startRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isExpired || _completed || _processing) return;
      try {
        final data = await ApiService.request(
            method: 'GET', path: '/payment-requests/${widget.requestId}');
        if (!mounted) return;
        final request = data['data'] as Map<String, dynamic>?;
        if (request == null) return;
        if (request['status']?.toString().toLowerCase() != 'pending') {
          setState(() {
            _updateStatusFromRequest(request);
          });
        }
        _startCountdown(request['expires_at']);
      } catch (_) {
        // ignore refresh failures; keep the dialog open
      }
    });
  }

  void _startCountdown(dynamic expiresAt) {
    _timer?.cancel();
    if (expiresAt == null) return;

    final expiry = DateTime.tryParse(expiresAt.toString());
    if (expiry == null) return;

    final now = DateTime.now();
    const maxWindowSeconds = 12 * 60 * 60;
    _secondsRemaining =
        expiry.difference(now).inSeconds.clamp(0, maxWindowSeconds);
    if (_secondsRemaining <= 0) {
      if (mounted) {
        setState(() {
          _isExpired = true;
          _statusMessage = 'Request expired';
        });
      }
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining = expiry.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isExpired = true;
          _statusMessage = 'Request expired';
        });
        return;
      }
      setState(() => _secondsRemaining = remaining);
    });
  }

  Future<void> _approve() async {
    if (_processing || _isExpired) return;

    final authResult = await TransactionAuthorizationService()
        .authorizeTransaction(
          localizedReason: 'Approve money request',
        )
        .then((result) => result.toTransactionAuthenticationResult());

    String? pin;
    if (authResult.biometricUsed != true) {
      final entered = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          final controller = TextEditingController();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('common.pin_required'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'common.pin'.tr()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: Text('common.confirm'.tr()),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (entered == null || entered.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('common.pin_required'.tr())));
        return;
      }
      pin = entered;
    }

    setState(() => _processing = true);
    try {
      final res = await ApiService.request(
        method: 'POST',
        path: '/payment-requests/accept',
        body: {
          'request_id': widget.requestId,
          if (authResult.biometricUsed != true) 'pin': pin,
          if (authResult.biometricUsed == true) 'biometric_auth': true,
          if (authResult.deviceFingerprint != null)
            'device_fingerprint': authResult.deviceFingerprint,
        },
      );
      await AppSessionManager().syncNow(
        profileTimeoutSeconds: 5,
        walletTimeoutSeconds: 5,
        transactionsTimeoutSeconds: 5,
      );
      setState(() {
        _completed = true;
        _statusMessage = res['message'] ?? 'Payment request approved';
      });
      if (!widget.compact) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_statusMessage ?? 'Approved')));
      }
    } catch (e) {
      final message = userErrorMessage(e);
      setState(() {
        _error = message;
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _decline() async {
    if (_processing || _completed) return;
    setState(() => _processing = true);
    try {
      final res = await ApiService.request(
          method: 'POST', path: '/payment-requests/${widget.requestId}/reject');
      setState(() {
        _completed = true;
        _statusMessage = res['message'] ?? 'Request declined';
      });
      if (!widget.compact) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_statusMessage ?? 'Declined')));
      }
    } catch (e) {
      final message = userErrorMessage(e);
      setState(() {
        _error = message;
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 40),
                const SizedBox(height: 8),
                Text('common.request_load_failed'.tr(),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('common.retrying_request'.tr(),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};
        final request = data['data'] is Map
            ? Map<String, dynamic>.from(data['data'] as Map)
            : <String, dynamic>{};
        final requester = request['requester'] is Map
            ? Map<String, dynamic>.from(request['requester'] as Map)
            : request['users_requester'] is Map
                ? Map<String, dynamic>.from(request['users_requester'] as Map)
                : <String, dynamic>{};
        final requesterName = [requester['first_name'], requester['last_name']]
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .join(' ')
            .trim();
        final displayName = requesterName.isNotEmpty
            ? requesterName
            : (requester['username'] ?? 'Unknown user');
        final profileImage = requester['profile_image']?.toString() ?? '';
        final amount = request['amount'] ?? 0;
        final reason = request['reason']?.toString().trim().isNotEmpty == true
            ? request['reason'].toString()
            : request['description']?.toString().trim().isNotEmpty == true
                ? request['description'].toString()
                : 'No reason provided';
        final createdAt = request['created_at']?.toString() ?? '';
        final canAct = !_isExpired &&
            !_completed &&
            !_processing &&
            (request['status']?.toString().toLowerCase() == 'pending' ||
                request['status']?.toString().toLowerCase() == 'accepted' ||
                request['status']?.toString().toLowerCase() == 'completed');

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.deepPurple.shade50,
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                    child: profileImage.isEmpty
                        ? const Icon(Icons.person, color: Colors.deepPurple)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            '${'common.requested'.tr()} ${amount.toString()} FARM',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.35),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('common.reason'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(reason, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 12),
                    Text('common.created'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        createdAt.isNotEmpty
                            ? createdAt
                            : 'common.just_now'.tr(),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Text('common.time_remaining'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        _isExpired
                            ? 'common.expired'.tr()
                            : '$_secondsRemaining s',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _isExpired
                                ? Colors.redAccent
                                : Colors.deepPurple)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ),
              if (_statusMessage != null && _completed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_statusMessage!,
                              style: const TextStyle(color: Colors.green))),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (canAct)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _decline,
                            icon: const Icon(Icons.close_rounded),
                            label: Text('common.decline'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                _processing || _isExpired ? null : _approve,
                            icon: _processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.payment_rounded),
                            label: Text(_processing
                                ? 'common.working'.tr()
                                : 'common.pay'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _processing
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: Text('common.cancel'.tr()),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock_clock),
                    label: Text(_isExpired
                        ? 'common.request_expired'.tr()
                        : 'common.already_handled'.tr()),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (widget.compact) {
      return Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 760),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: content,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: Text('common.money_request_approval'.tr()),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: content,
        ),
      ),
    );
  }
}
