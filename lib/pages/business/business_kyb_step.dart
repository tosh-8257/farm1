import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/services/api_service.dart';
import 'business_kyb_logic.dart';
import 'business_ui.dart';

/// "Verify business" step: opens Didit's hosted KYB link, like personal KYC.
/// The Didit result is advisory; FARM compliance approves manually.
class BusinessKybStep extends StatefulWidget {
  const BusinessKybStep({super.key, this.initialStatus});

  /// Normalised Didit KYB status from `/business/me` (`didit_kyb_status`).
  final String? initialStatus;

  @override
  State<BusinessKybStep> createState() => _BusinessKybStepState();
}

class _BusinessKybStepState extends State<BusinessKybStep> {
  late KybUiState _state = kybStateFor(widget.initialStatus);
  bool _busy = false;
  String? _error;

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getDiditKybStatus();
      final data = resp['data'] is Map ? resp['data'] as Map : resp;
      if (mounted) {
        setState(() => _state = kybStateFor(data['status']?.toString()));
      }
    } catch (e) {
      if (mounted) setState(() => _error = kybErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ApiService.createDiditKybSession();
      final url = session['url'];
      if (url is! String || url.isEmpty) {
        throw const FormatException('invalid Didit session');
      }
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('could not open Didit');
      if (mounted) setState(() => _state = KybUiState.pending);
    } catch (e) {
      if (mounted) setState(() => _error = kybErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData get _icon => switch (_state) {
        KybUiState.verified => Icons.verified_outlined,
        KybUiState.declined => Icons.cancel_outlined,
        KybUiState.inReview || KybUiState.pending => Icons.hourglass_top,
        KybUiState.actionNeeded => Icons.info_outline,
        KybUiState.notStarted => Icons.domain_verification_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BizCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, color: fgColor(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kybTitle(_state),
                      key: const Key('kyb-title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fgColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kybBody(_state),
                style: TextStyle(color: mutedColor(context), height: 1.5),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          BizCard(
            child: Row(
              children: [
                Icon(Icons.error_outline, color: fgColor(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    key: const Key('kyb-error'),
                    style: TextStyle(color: fgColor(context), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(key: Key('kyb-loading')),
            ),
          )
        else ...[
          if (kybCanStart(_state))
            ElevatedButton(
              key: const Key('kyb-start'),
              style: primaryButtonStyle(context),
              onPressed: _start,
              child: Text(kybStartLabel(_state)),
            ),
          if (_state != KybUiState.notStarted) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('kyb-refresh'),
              style: secondaryButtonStyle(context),
              onPressed: _refresh,
              child: const Text('Refresh status'),
            ),
          ],
        ],
        const SizedBox(height: 12),
        Text(
          'This step is recommended. You can continue without it; FARM compliance reviews every application manually.',
          style: TextStyle(color: mutedColor(context), fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}
