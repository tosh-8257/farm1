import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/services/api_service.dart';
import '/services/auth/device_identity.dart';
import 'otp_code_input.dart';

const _black = Colors.black;
const _grey = Color(0xFF6B6B6B);
const _light = Color(0xFFF2F2F2);

enum _Step { waiting, sendingCode, enterCode, idCheck, finishing, error }

/// Shown when login comes from an untrusted phone. Pops `true` once this
/// device is trusted (approved elsewhere or recovered) so login can retry.
class NewDevicePage extends StatefulWidget {
  const NewDevicePage({super.key, required this.pendingDeviceId});

  final String pendingDeviceId;

  @override
  State<NewDevicePage> createState() => _NewDevicePageState();
}

class _NewDevicePageState extends State<NewDevicePage> {
  _Step _step = _Step.waiting;
  String? _error;
  String? _recoveryId;
  String? _phoneHint;
  String? _idCheckUrl;
  String _idStatus = '';
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _startApprovalPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startApprovalPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _checkApproval());
    _checkApproval();
  }

  Future<void> _checkApproval() async {
    try {
      final id = await DeviceIdentity.instance.deviceId();
      final res = await ApiService.pendingDeviceStatus(
        pendingDeviceId: widget.pendingDeviceId,
        deviceId: id,
      );
      final status = (res['data'] as Map?)?['status']?.toString() ?? '';
      if (!mounted) return;
      if (status == 'trusted') {
        _poll?.cancel();
        Navigator.of(context).pop(true);
      } else if (status == 'rejected' || status == 'expired') {
        _poll?.cancel();
        setState(() {
          _step = _Step.error;
          _error = status == 'rejected'
              ? 'This sign-in was rejected on your trusted phone.'
              : 'The approval request expired. Sign in again.';
        });
      }
    } catch (_) {
      // Keep polling quietly; network blips are expected.
    }
  }

  Future<void> _startRecovery() async {
    setState(() {
      _step = _Step.sendingCode;
      _error = null;
    });
    try {
      final id = await DeviceIdentity.instance.deviceId();
      final res = await ApiService.startDeviceRecovery(
        pendingDeviceId: widget.pendingDeviceId,
        deviceId: id,
      );
      final data = (res['data'] as Map?) ?? {};
      if (!mounted) return;
      setState(() {
        _recoveryId = data['recovery_id']?.toString();
        _phoneHint = data['phone_hint']?.toString();
        _step = _Step.enterCode;
      });
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _verifyCode(String code) async {
    if (_recoveryId == null || _busy) return;
    setState(() => _busy = true);
    try {
      final id = await DeviceIdentity.instance.deviceId();
      final res = await ApiService.verifyDeviceRecoveryOtp(
        recoveryId: _recoveryId!,
        deviceId: id,
        otp: code,
      );
      final url = (res['data'] as Map?)?['id_check_url']?.toString();
      if (!mounted) return;
      setState(() {
        _idCheckUrl = url;
        _step = _Step.idCheck;
        _busy = false;
      });
      await _openIdCheck();
      _poll?.cancel();
      _poll = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkRecovery(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _openIdCheck() async {
    final url = _idCheckUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _checkRecovery() async {
    if (_recoveryId == null) return;
    try {
      final id = await DeviceIdentity.instance.deviceId();
      final res = await ApiService.deviceRecoveryStatus(
        recoveryId: _recoveryId!,
        deviceId: id,
      );
      final idCheck = (res['data'] as Map?)?['id_check']?.toString() ?? '';
      if (!mounted) return;
      setState(() => _idStatus = idCheck);
      if (idCheck == 'Approved') {
        _poll?.cancel();
        setState(() => _step = _Step.finishing);
        await ApiService.completeDeviceRecovery(
          recoveryId: _recoveryId!,
          deviceId: id,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else if (idCheck == 'Declined') {
        _poll?.cancel();
        setState(() {
          _step = _Step.error;
          _error = 'The ID check was declined. Contact support.';
        });
      }
    } catch (e) {
      if (_step == _Step.finishing) _fail(e);
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _step = _Step.error;
      _error = _message(e);
    });
  }

  String _message(Object e) {
    if (e is ApiServiceException) return e.message;
    return 'Something went wrong. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _black,
        elevation: 0,
        title: const Text('New device'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(key: ValueKey(_step), child: _body()),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.waiting:
        return _column(
          icon: Icons.phonelink_lock_outlined,
          title: 'Approve on your other phone',
          text:
              'This phone is not trusted yet. Open FARM on your trusted phone and tap Approve. This screen continues by itself.',
          children: [
            const LinearProgressIndicator(
              color: _black,
              backgroundColor: _light,
            ),
            const SizedBox(height: 32),
            _secondary(
              'No access to that phone? Recover with ID',
              _startRecovery,
            ),
          ],
        );
      case _Step.sendingCode:
      case _Step.finishing:
        return _column(
          icon: Icons.hourglass_empty_rounded,
          title: _step == _Step.finishing
              ? 'Moving your account to this phone'
              : 'Sending a code',
          text: 'One moment…',
          children: const [CircularProgressIndicator(color: _black)],
        );
      case _Step.enterCode:
        return _column(
          icon: Icons.sms_outlined,
          title: 'Enter the SMS code',
          text: 'We sent a 6-digit code to ${_phoneHint ?? 'your phone'}.',
          children: [
            OtpCodeInput(
              useRetriever: true,
              busy: _busy,
              onCompleted: _verifyCode,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _black)),
            ],
          ],
        );
      case _Step.idCheck:
        return _column(
          icon: Icons.badge_outlined,
          title: 'Verify your ID',
          text: _idStatus.isEmpty || _idStatus == 'Not Started'
              ? 'Finish the ID and selfie check in the browser. Your other devices will be signed out once it is approved.'
              : 'ID check status: $_idStatus. We will continue automatically.',
          children: [
            const LinearProgressIndicator(
              color: _black,
              backgroundColor: _light,
            ),
            const SizedBox(height: 24),
            _primary('Open ID check', _openIdCheck),
          ],
        );
      case _Step.error:
        return _column(
          icon: Icons.error_outline,
          title: 'Could not continue',
          text: _error ?? 'Something went wrong.',
          children: [
            _primary('Back to sign in', () => Navigator.of(context).pop(false)),
          ],
        );
    }
  }

  Widget _column({
    required IconData icon,
    required String title,
    required String text,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(icon, size: 56, color: _black),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _black,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _grey, height: 1.4),
        ),
        const SizedBox(height: 32),
        ...children,
      ],
    );
  }

  Widget _primary(String label, VoidCallback onTap) => SizedBox(
    height: 52,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    ),
  );

  Widget _secondary(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: _black),
    child: Text(label),
  );
}
