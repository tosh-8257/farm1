import '/components/fee_line.dart';
import '/backend/services/api_service.dart';
import '/components/action_circle/action_circle_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
// replaced direct wallet API calls with centralized ApiService
import '/services/app_session_manager.dart';
import '/services/branded_qr_card_service.dart';
import '/services/qr_download_service.dart';
import '/services/transaction_authentication_service.dart';
import '/services/transaction_authorization_service.dart';
import '/utils/merchant_qr_parser.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'q_r_scanner_model.dart';
export 'q_r_scanner_model.dart';

class QRScannerWidget extends StatefulWidget {
  const QRScannerWidget({super.key});

  static String routeName = 'QRScanner';
  static String routePath = '/qRScanner';

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter(this.scanRect);

  final Rect scanRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanRect.isEmpty) return;

    final cornerLength = (scanRect.width * 0.16).clamp(28.0, 52.0);
    final cornerGuide = Paint()
      ..color = const Color(0xFFFFC857)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final corners = Path()
      ..moveTo(scanRect.left + cornerLength, scanRect.top)
      ..lineTo(scanRect.left + 24, scanRect.top)
      ..quadraticBezierTo(
        scanRect.left,
        scanRect.top,
        scanRect.left,
        scanRect.top + 24,
      )
      ..lineTo(scanRect.left, scanRect.top + cornerLength)
      ..moveTo(scanRect.right - cornerLength, scanRect.top)
      ..lineTo(scanRect.right - 24, scanRect.top)
      ..quadraticBezierTo(
        scanRect.right,
        scanRect.top,
        scanRect.right,
        scanRect.top + 24,
      )
      ..lineTo(scanRect.right, scanRect.top + cornerLength)
      ..moveTo(scanRect.left + cornerLength, scanRect.bottom)
      ..lineTo(scanRect.left + 24, scanRect.bottom)
      ..quadraticBezierTo(
        scanRect.left,
        scanRect.bottom,
        scanRect.left,
        scanRect.bottom - 24,
      )
      ..lineTo(scanRect.left, scanRect.bottom - cornerLength)
      ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
      ..lineTo(scanRect.right - 24, scanRect.bottom)
      ..quadraticBezierTo(
        scanRect.right,
        scanRect.bottom,
        scanRect.right,
        scanRect.bottom - 24,
      )
      ..lineTo(scanRect.right, scanRect.bottom - cornerLength);
    canvas.drawPath(corners, cornerGuide);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scanRect != scanRect;
}

class _QRScannerWidgetState extends State<QRScannerWidget>
    with SingleTickerProviderStateMixin {
  late QRScannerModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final MobileScannerController cameraController = MobileScannerController();
  late final AnimationController _scanLineController;

  bool isProcessing = false;
  bool isSubmittingTransfer = false;

  double walletBalance = 0.0;
  bool balanceLoading = true;

  @override
  void initState() {
    super.initState();

    _model = createModel(context, () => QRScannerModel());
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      setState(() => balanceLoading = true);

      final resp = await ApiService.getWallet();
      setState(() {
        walletBalance = double.tryParse(
                (resp['data']?['balance'] ?? resp['balance'] ?? 0)
                    .toString()) ??
            0.0;
        balanceLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to fetch wallet balance: $e');
      setState(() {
        walletBalance = 0.0;
        balanceLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    cameraController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _showPaymentSheet({
    required String recipientIdentifier,
    String? recipientLabel,
    String? suggestedAmount,
  }) async {
    final amountController = TextEditingController(
      text: suggestedAmount ?? '',
    );
    final pinController = TextEditingController();
    final descriptionController = TextEditingController(text: 'QR payment');

    final pinFocusNode = FocusNode();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool pinEntryEnabled = false;
        bool isBiometricChecking = false;
        TransactionAuthenticationResult? authResult;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                top: 20,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'common.send'.tr(),
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipientLabel != null && recipientLabel.isNotEmpty
                            ? '${'common.send'.tr()} $recipientLabel'
                            : '${'common.send'.tr()} $recipientIdentifier',
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'common.amount'.tr(),
                          prefixText: 'FARM ',
                        ),
                      ),
                      FeeLine(feeKey: 'transfer', amount: double.tryParse(amountController.text.trim()) ?? 0),
                      const SizedBox(height: 12),
                      if (pinEntryEnabled || !isBiometricChecking)
                        TextField(
                          controller: pinController,
                          focusNode: pinFocusNode,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          readOnly: !pinEntryEnabled || isBiometricChecking,
                          onTap: () async {
                            if (authResult?.biometricUsed == true) {
                              return;
                            }
                            if (!pinEntryEnabled && !isBiometricChecking) {
                              setState(() => isBiometricChecking = true);
                              final result =
                                  await TransactionAuthorizationService()
                                      .authorizeTransaction(
                                        localizedReason: 'Confirm transfer',
                                      )
                                      .then((r) => r
                                          .toTransactionAuthenticationResult());
                              if (!mounted) return;

                              if (result.biometricUsed) {
                                authResult = result;
                                setState(() => isBiometricChecking = false);

                                try {
                                  final amount = double.tryParse(
                                          amountController.text.trim()) ??
                                      0;
                                  await ApiService.request(
                                    method: 'POST',
                                    path: '/wallet/send',
                                    body: {
                                      'recipient_identifier':
                                          recipientIdentifier,
                                      'amount': amount,
                                      'pin': null,
                                      'description': descriptionController.text
                                              .trim()
                                              .isNotEmpty
                                          ? descriptionController.text.trim()
                                          : 'QR payment',
                                      'biometric_auth': true,
                                      'device_fingerprint':
                                          authResult?.deviceFingerprint,
                                    },
                                  );

                                  if (!mounted) return;
                                  await AppSessionManager().syncNow(
                                    profileTimeoutSeconds: 5,
                                    walletTimeoutSeconds: 5,
                                    transactionsTimeoutSeconds: 5,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      walletBalance =
                                          FFAppState().walletBalance;
                                      balanceLoading = false;
                                    });
                                  }
                                  Navigator.of(sheetContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'common.transaction_success'.tr())),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${'common.transaction_failed'.tr()}: ${e.toString().replaceFirst('Exception: ', '')}',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              setState(() {
                                authResult = result;
                                pinEntryEnabled = true;
                                isBiometricChecking = false;
                              });
                              pinFocusNode.requestFocus();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'common.pin'.tr(),
                            suffixIcon: isBiometricChecking
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : null,
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: 'common.description'.tr(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmittingTransfer
                              ? null
                              : () async {
                                  final amount = double.tryParse(
                                          amountController.text.trim()) ??
                                      0;
                                  final pin = pinController.text.trim();

                                  if (amount <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('common.amount'.tr()),
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    if (!mounted) return;
                                    setState(() => isSubmittingTransfer = true);

                                    authResult ??=
                                        await TransactionAuthorizationService()
                                            .authorizeTransaction(
                                              localizedReason:
                                                  'Confirm transfer',
                                            )
                                            .then((r) => r
                                                .toTransactionAuthenticationResult());

                                    if (authResult?.biometricUsed == true) {
                                      await ApiService.request(
                                        method: 'POST',
                                        path: '/wallet/send',
                                        body: {
                                          'recipient_identifier':
                                              recipientIdentifier,
                                          'amount': amount,
                                          'pin': null,
                                          'description': descriptionController
                                                  .text
                                                  .trim()
                                                  .isNotEmpty
                                              ? descriptionController.text
                                                  .trim()
                                              : 'QR payment',
                                          'biometric_auth': true,
                                          'device_fingerprint':
                                              authResult?.deviceFingerprint,
                                        },
                                      );
                                    } else {
                                      if (pin.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Enter your PIN'),
                                          ),
                                        );
                                        return;
                                      }

                                      await ApiService.request(
                                        method: 'POST',
                                        path: '/wallet/send',
                                        body: {
                                          'recipient_identifier':
                                              recipientIdentifier,
                                          'amount': amount,
                                          'pin': pin,
                                          'description': descriptionController
                                                  .text
                                                  .trim()
                                                  .isNotEmpty
                                              ? descriptionController.text
                                                  .trim()
                                              : 'QR payment',
                                        },
                                      );
                                    }

                                    if (!mounted) return;
                                    await AppSessionManager().syncNow(
                                      profileTimeoutSeconds: 5,
                                      walletTimeoutSeconds: 5,
                                      transactionsTimeoutSeconds: 5,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        walletBalance =
                                            FFAppState().walletBalance;
                                        balanceLoading = false;
                                      });
                                    }
                                    Navigator.of(sheetContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Transfer successful'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Transfer failed: ${e.toString().replaceFirst('Exception: ', '')}',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (!mounted) return;
                                    setState(
                                        () => isSubmittingTransfer = false);
                                  }
                                },
                          child: isSubmittingTransfer
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Send payment'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> validateQr(String qrPayload) async {
    if (isProcessing) return;

    isProcessing = true;

    try {
      final localMerchantQr = parseMerchantQrPayload(qrPayload);
      if (localMerchantQr != null) {
        if (mounted) {
          context.pushNamed(
            'MerchantPayment',
            queryParameters: {
              'merchantId': localMerchantQr.merchantId,
              'businessName': localMerchantQr.businessName,
              'qrPayload': qrPayload,
            },
          );
        }
        return;
      }

      final data = await ApiService.request(
          method: 'POST',
          path: '/qr/validate',
          body: {'qr_payload': qrPayload});
      final qrData = data['data'] ?? data;

      debugPrint(qrData.toString());

      if (qrData != null) {
        if (qrData['type'] == 'peer') {
          final recipientIdentifier = qrData['wallet_address']?.toString() ??
              qrData['recipient_identifier']?.toString() ??
              qrData['username']?.toString() ??
              qrData['phone']?.toString() ??
              '';

          if (recipientIdentifier.isNotEmpty) {
            if (mounted) {
              await _showPaymentSheet(
                recipientIdentifier: recipientIdentifier,
                recipientLabel: qrData['display_name']?.toString() ??
                    qrData['username']?.toString() ??
                    qrData['phone']?.toString(),
                suggestedAmount: qrData['suggested_amount']?.toString(),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to determine recipient from QR code'),
                ),
              );
            }
          }
        } else if (qrData['type'] == 'merchant') {
          context.pushNamed(
            'MerchantPayment',
            queryParameters: {
              'merchantId': qrData['merchant_id']?.toString() ?? '',
              'businessName': qrData['business_name']?.toString() ??
                  qrData['display_name']?.toString() ??
                  'Merchant',
              'qrPayload': qrPayload,
            },
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR Code'),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR Validation Error: $e',
          ),
        ),
      );
    }

    isProcessing = false;
  }

  Future<void> scanFromGallery() async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    final file = File(image.path);

    final barcodeCapture = await cameraController.analyzeImage(file.path);

    if (barcodeCapture == null || barcodeCapture.barcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No QR found in image")),
      );
      return;
    }

    final code = barcodeCapture.barcodes.first.rawValue;

    if (code != null) {
      await validateQr(code);
    }
  }

  void scanByUsername() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Scan by Username / Phone"),
          content: StatefulBuilder(
            builder: (context, setState) {
              List<dynamic> suggestionUsers = [];

              Future<void> searchUsers(String value) async {
                if (value.trim().length < 3) {
                  setState(() => suggestionUsers = []);
                  return;
                }

                try {
                  final resp = await ApiService.searchUsers(value.trim());
                  final users = resp['data'] ?? resp;
                  if (!mounted) return;
                  setState(() => suggestionUsers = users);
                } catch (_) {
                  if (!mounted) return;
                  setState(() => suggestionUsers = []);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          hintText: 'Recipient username or phone number',
                          helperText:
                              'You can scan by username or phone number',
                          helperStyle: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) async {
                          controller.text = value;
                          await searchUsers(value);
                        },
                        onSubmitted: (_) async {
                          final input = controller.text.trim();
                          if (input.isEmpty) return;
                          Navigator.pop(context);
                          await validateQr(input);
                        },
                      ),
                      if (suggestionUsers.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            children: suggestionUsers.map((u) {
                              final user = u as Map<String, dynamic>;
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  child: Text(
                                    (user['username'] ?? 'u')
                                            .toString()
                                            .trim()
                                            .isNotEmpty
                                        ? (user['username'] ?? 'u')
                                            .toString()
                                            .trim()[0]
                                            .toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text((user['username'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty
                                    ? '@${(user['username'] ?? '').toString().trim()}${((user['phone'] ?? '').toString().trim().isNotEmpty) ? ' • ${(user['phone'] ?? '').toString().trim()}' : ''}'
                                    : (user['phone'] ?? '').toString().trim()),
                                onTap: () {
                                  controller.text = ((user['username'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty
                                      ? (user['username'] ?? '')
                                          .toString()
                                          .trim()
                                      : (user['phone'] ?? '')
                                          .toString()
                                          .trim());
                                  setState(() => suggestionUsers = []);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = controller.text.trim();
                if (input.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a username or phone number to scan'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await validateQr(input);
              },
              child: Text("Scan"),
            ),
          ],
        );
      },
    );
  }

  Future<void> showMyQrCode() async {
    final username = FFAppState().userName.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your username is not available yet.')),
      );
      return;
    }

    try {
      final qrCard = await BrandedQrCardService.createPersonalCard(username);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return Dialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0xFFD6B36A), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.qr_code_2_rounded,
                        color: Color(0xFFD6B36A),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Your FARM Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      qrCard,
                      width: 290,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadMyQr(qrCard),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Save'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFAF8F1),
                            side: const BorderSide(color: Color(0xFFD6B36A)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _shareMyQr(qrCard),
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD6B36A),
                            foregroundColor: const Color(0xFF0B211C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create your QR code: $error')),
      );
    }
  }

  Future<void> _downloadMyQr(Uint8List bytes) async {
    final result = await QrDownloadService.instance.downloadQr(
      bytes,
      fileName: 'farm_personal_qr_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _shareMyQr(Uint8List bytes) async {
    try {
      await QrDownloadService.instance.shareQr(
        bytes,
        fileName:
            'farm_personal_qr_${DateTime.now().millisecondsSinceEpoch}.png',
        subject: 'Your FARM Africa QR code',
        text: 'Scan my FARM Africa QR code to pay me.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share your QR code: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MobileScanner(
                fit: BoxFit.cover,
                controller: cameraController,
                onDetect: (capture) async {
                  for (final barcode in capture.barcodes) {
                    final code = barcode.rawValue;
                    if (code != null) {
                      await validateQr(code);
                      break;
                    }
                  }
                },
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final frameWidth =
                    (constraints.maxWidth - 24).clamp(0.0, 440.0).toDouble();
                final frameHeight =
                    (constraints.maxHeight * 0.48).clamp(0.0, 440.0).toDouble();
                final frameLeft = (constraints.maxWidth - frameWidth) / 2;
                final frameTop = (constraints.maxHeight - frameHeight) / 2;
                final scanRect = Rect.fromLTWH(
                  frameLeft,
                  frameTop,
                  frameWidth,
                  frameHeight,
                );

                return IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _ScannerOverlayPainter(scanRect),
                      ),
                      if (frameWidth > 0 && frameHeight > 0)
                        AnimatedBuilder(
                          animation: _scanLineController,
                          builder: (context, _) {
                            final lineTravel = frameHeight - 36;
                            return Positioned(
                              left: frameLeft + 16,
                              right: constraints.maxWidth -
                                  frameLeft -
                                  frameWidth +
                                  16,
                              top: frameTop +
                                  18 +
                                  lineTravel * _scanLineController.value,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC857),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFC857)
                                          .withValues(alpha: 0.8),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
            SafeArea(
              child: Column(
                children: [
                  /// TOP BAR
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FlutterFlowIconButton(
                          borderRadius: 9999,
                          buttonSize: 44,
                          fillColor: FlutterFlowTheme.of(context).onPrimary13,
                          icon: Icon(
                            Icons.close_rounded,
                            color: FlutterFlowTheme.of(context).onPrimary,
                            size: 24,
                          ),
                          onPressed: () {
                            context.goNamed('Dashboard');
                          },
                        ),
                        Text(
                          'Scan QR Code',
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: FlutterFlowTheme.of(context).onPrimary,
                              ),
                        ),
                        FlutterFlowIconButton(
                          borderRadius: 9999,
                          buttonSize: 44,
                          fillColor: FlutterFlowTheme.of(context).onPrimary13,
                          icon: Icon(
                            Icons.flash_on_rounded,
                            color: FlutterFlowTheme.of(context).onPrimary,
                            size: 24,
                          ),
                          onPressed: () async {
                            await cameraController.toggleTorch();
                          },
                        ),
                      ],
                    ),
                  ),

                  const Expanded(child: SizedBox.shrink()),

                  const SizedBox(height: 24),

                  Opacity(
                    opacity: 0.9,
                    child: Text(
                      'Align QR code within the frame',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(),
                            color: FlutterFlowTheme.of(context).onPrimary,
                          ),
                    ),
                  ),

                  /// ACTION BUTTONS
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        wrapWithModel(
                          model: _model.actionCircleModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: GestureDetector(
                            onTap: scanFromGallery,
                            child: ActionCircleWidget(
                              icon: Icon(
                                Icons.image_rounded,
                                color: FlutterFlowTheme.of(context).onPrimary,
                                size: 24,
                              ),
                              label: 'Gallery',
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        wrapWithModel(
                          model: _model.actionCircleModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: GestureDetector(
                            onTap: scanByUsername,
                            child: ActionCircleWidget(
                              icon: Icon(
                                Icons.person_search_rounded,
                                color: FlutterFlowTheme.of(context).onPrimary,
                                size: 24,
                              ),
                              label: 'Username / Phone',
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        wrapWithModel(
                          model: _model.actionCircleModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: GestureDetector(
                            onTap: showMyQrCode,
                            child: ActionCircleWidget(
                              icon: Icon(
                                Icons.qr_code_2_rounded,
                                color: FlutterFlowTheme.of(context).onPrimary,
                                size: 24,
                              ),
                              label: 'My Code',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// USER CARD
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 32,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).onPrimary,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).primary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                FFAppState().userName.isNotEmpty
                                    ? FFAppState()
                                        .userName
                                        .substring(0, 2)
                                        .toUpperCase()
                                    : 'US',
                                style: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .onPrimary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sending from @${FFAppState().userName}',
                                  style:
                                      FlutterFlowTheme.of(context).labelSmall,
                                ),
                                Text(
                                  balanceLoading
                                      ? 'Balance: Loading...'
                                      : 'Balance: ${walletBalance.toStringAsFixed(2)} FARM',
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
