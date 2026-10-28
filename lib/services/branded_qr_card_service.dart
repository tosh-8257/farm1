import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BrandedQrCardService {
  BrandedQrCardService._();

  static const _canvasWidth = 1000;
  static const _canvasHeight = 1320;
  static const _forest = Colors.black;
  static const _emerald = Colors.black;
  static const _gold = Color(0xFFD6B36A);
  static const _ivory = Color(0xFFFAF8F1);

  static Future<Uint8List> createPersonalCard(String username) async {
    final qrData = await QrPainter(
      data: username,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.white,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.white,
      ),
    ).toImageData(680, format: ui.ImageByteFormat.png);

    if (qrData == null) {
      throw StateError('Unable to generate your personal QR code.');
    }

    return createBrandedCard(
      qrBytes: qrData.buffer.asUint8List(),
      displayName: '@$username',
      category: 'PERSONAL CODE',
    );
  }

  static Future<Uint8List> createBrandedCard({
    required Uint8List qrBytes,
    required String displayName,
    required String category,
    bool invertQrColors = false,
  }) async {
    final codec = await ui.instantiateImageCodec(qrBytes);
    final frame = await codec.getNextFrame();
    final qrImage = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(
      0,
      0,
      _canvasWidth.toDouble(),
      _canvasHeight.toDouble(),
    );

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_forest, _emerald, _forest],
        ).createShader(bounds),
    );

    final border = RRect.fromRectAndRadius(
      const Rect.fromLTWH(34, 34, 932, 1252),
      const Radius.circular(44),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _gold.withAlpha(210),
    );

    _drawCenteredText(
      canvas,
      'FARM AFRICA',
      top: 78,
      maxWidth: 840,
      fontSize: 40,
      color: _ivory,
      fontWeight: FontWeight.bold,
      letterSpacing: 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(360, 146, 280, 5),
        const Radius.circular(3),
      ),
      Paint()..color = _gold,
    );
    _drawCenteredText(
      canvas,
      category.toUpperCase(),
      top: 184,
      maxWidth: 760,
      fontSize: 22,
      color: _gold,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    );
    _drawCenteredText(
      canvas,
      displayName.trim().isEmpty ? 'FARM Member' : displayName.trim(),
      top: 242,
      maxWidth: 850,
      fontSize: 44,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );
    _drawCenteredText(
      canvas,
      'Scan to pay',
      top: 306,
      maxWidth: 700,
      fontSize: 27,
      color: _ivory.withAlpha(220),
    );

    final qrPanel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(130, 370, 740, 740),
      const Radius.circular(42),
    );
    canvas.drawRRect(
      qrPanel,
      Paint()
        ..color = Colors.black
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      qrPanel,
      Paint()..color = Colors.black,
    );
    final qrImageBounds = const Rect.fromLTWH(190, 430, 620, 620);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(qrImageBounds, const Radius.circular(28)),
    );
    canvas.drawImageRect(
      qrImage,
      Rect.fromLTWH(
        0,
        0,
        qrImage.width.toDouble(),
        qrImage.height.toDouble(),
      ),
      qrImageBounds,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = invertQrColors
            ? const ui.ColorFilter.matrix([
                -1,
                0,
                0,
                0,
                255,
                0,
                -1,
                0,
                0,
                255,
                0,
                0,
                -1,
                0,
                255,
                0,
                0,
                0,
                1,
                0,
              ])
            : null,
    );
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(250, 1160, 500, 64),
        const Radius.circular(32),
      ),
      Paint()..color = _gold,
    );
    _drawCenteredText(
      canvas,
      'A SMARTER WAY TO PAY',
      top: 1178,
      maxWidth: 470,
      fontSize: 20,
      color: _forest,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    );

    final image =
        await recorder.endRecording().toImage(_canvasWidth, _canvasHeight);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    qrImage.dispose();
    codec.dispose();
    if (data == null) {
      throw StateError('Unable to render the branded QR card.');
    }
    return data.buffer.asUint8List();
  }

  static void _drawCenteredText(
    Canvas canvas,
    String value, {
    required double top,
    required double maxWidth,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset((_canvasWidth - painter.width) / 2, top),
    );
  }
}
