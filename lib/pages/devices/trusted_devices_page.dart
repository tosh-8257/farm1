import 'package:flutter/material.dart';

import '/backend/services/api_service.dart';

const _black = Colors.black;
const _grey = Color(0xFF6B6B6B);
const _light = Color(0xFFF2F2F2);

/// Settings › Trusted devices. Lists devices, approves/rejects pending ones
/// (only works from a trusted phone) and revokes old ones.
class TrustedDevicesPage extends StatefulWidget {
  const TrustedDevicesPage({super.key});

  @override
  State<TrustedDevicesPage> createState() => _TrustedDevicesPageState();
}

class _TrustedDevicesPageState extends State<TrustedDevicesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];
  String? _actingOn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.listTrustedDevices();
      final list = (res['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _devices = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiServiceException
            ? e.message
            : 'Could not load your devices.';
      });
    }
  }

  Future<void> _act(Map<String, dynamic> d, String action) async {
    if (action == 'revoke') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Remove this device?'),
          content: Text(
            '${d['name'] ?? 'This device'} will be signed out and must be approved again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              style: TextButton.styleFrom(foregroundColor: _grey),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(foregroundColor: _black),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _actingOn = d['id'].toString());
    try {
      await ApiService.decideDevice(id: d['id'].toString(), action: action);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _black,
            content: Text(
              e is ApiServiceException
                  ? e.message
                  : 'Action failed. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actingOn = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _devices.where((d) => d['status'] == 'pending').toList();
    final others = _devices.where((d) => d['status'] != 'pending').toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _black,
        elevation: 0,
        title: const Text('Trusted devices'),
      ),
      body: RefreshIndicator(
        color: _black,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _black))
            : _error != null
            ? _state(
                Icons.cloud_off_outlined,
                _error!,
                action: TextButton(
                  onPressed: _load,
                  style: TextButton.styleFrom(foregroundColor: _black),
                  child: const Text('Try again'),
                ),
              )
            : _devices.isEmpty
            ? _state(
                Icons.devices_other_outlined,
                'No devices yet. The phone you sign in with next becomes trusted.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final d in pending) _approvalCard(d),
                  if (pending.isNotEmpty) const SizedBox(height: 8),
                  for (final d in others) _deviceTile(d),
                ],
              ),
      ),
    );
  }

  Widget _state(IconData icon, String text, {Widget? action}) => ListView(
    children: [
      const SizedBox(height: 120),
      Icon(icon, size: 48, color: _grey),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _grey),
        ),
      ),
      if (action != null) Center(child: action),
    ],
  );

  Widget _approvalCard(Map<String, dynamic> d) {
    final busy = _actingOn == d['id'].toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _black, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approve new device?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '${d['name'] ?? 'Unknown device'} (${d['platform'] ?? 'phone'}) is trying to sign in. Only approve if this is you.',
            style: const TextStyle(color: _grey),
          ),
          const SizedBox(height: 14),
          if (busy)
            const LinearProgressIndicator(
              color: _black,
              backgroundColor: _light,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _act(d, 'reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _black,
                      side: const BorderSide(color: _black),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _act(d, 'approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _deviceTile(Map<String, dynamic> d) {
    final status = d['status']?.toString() ?? '';
    final current = d['is_current'] == true;
    final lastSeen = DateTime.tryParse(d['last_seen_at']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _light,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(
          d['platform'] == 'ios'
              ? Icons.phone_iphone
              : Icons.phone_android_outlined,
          color: status == 'trusted' ? _black : _grey,
        ),
        title: Text(
          '${d['name'] ?? 'Device'}${current ? ' · this phone' : ''}',
          style: TextStyle(
            color: status == 'trusted' ? _black : _grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            status,
            if (lastSeen != null)
              'last seen ${lastSeen.toLocal().toString().substring(0, 16)}',
          ].join(' · '),
          style: const TextStyle(color: _grey),
        ),
        trailing: status == 'trusted' && !current
            ? (_actingOn == d['id'].toString()
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _black,
                      ),
                    )
                  : IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close, color: _black),
                      onPressed: () => _act(d, 'revoke'),
                    ))
            : null,
      ),
    );
  }
}
