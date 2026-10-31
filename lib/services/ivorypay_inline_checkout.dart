import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '/utils/user_error_message.dart';

class IvoryPayInlineCheckout extends StatefulWidget {
  const IvoryPayInlineCheckout({
    required this.paymentUrl,
    super.key,
  });

  final String paymentUrl;

  static Future<bool?> show(
    BuildContext context, {
    required String paymentUrl,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => IvoryPayInlineCheckout(paymentUrl: paymentUrl),
    );
  }

  @override
  State<IvoryPayInlineCheckout> createState() => _IvoryPayInlineCheckoutState();
}

class _IvoryPayInlineCheckoutState extends State<IvoryPayInlineCheckout> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final checkoutUri = Uri.tryParse(widget.paymentUrl);
    if (checkoutUri == null ||
        checkoutUri.scheme != 'https' ||
        checkoutUri.host != 'checkout.ivorypay.io') {
      setState(() {
        _loading = false;
        _error = 'IvoryPay did not provide a valid checkout link.';
      });
      return;
    }

    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'https' &&
                uri.host == 'farmapp.africa' &&
                uri.path.replaceAll(RegExp(r'/+$'), '') ==
                    '/payment-callback') {
              final callbackStatus = (uri.queryParameters['status'] ??
                      uri.queryParameters['payment_status'] ??
                      uri.queryParameters['transaction_status'] ??
                      '')
                  .toLowerCase();
              final isFailure = const {
                    'failed',
                    'failure',
                    'cancelled',
                    'canceled',
                    'error',
                  }.contains(callbackStatus) ||
                  uri.queryParameters['success']?.toLowerCase() == 'false';
              if (mounted) Navigator.of(context).pop(!isFailure);
              return NavigationDecision.prevent;
            }
            return uri.scheme == 'https'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
            }
          },
        ),
      );

      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(checkoutUri);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open IvoryPay checkout: ${userErrorMessage(error)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.94,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pay securely with IvoryPay',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close IvoryPay checkout',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                if (controller != null)
                  WebViewWidget(
                    controller: controller,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<VerticalDragGestureRecognizer>(
                        VerticalDragGestureRecognizer.new,
                      ),
                    },
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          if (controller != null)
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                  _loading = true;
                                });
                                controller.reload();
                              },
                              child: const Text('Retry'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
