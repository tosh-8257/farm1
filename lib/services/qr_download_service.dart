import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/user_error_message.dart';

import 'qr_web_stub.dart'
    if (dart.library.html) 'qr_web_impl.dart' as qr_web;

const _kQrDownloadChannel = 'farm.qr_download_service';

enum QrDownloadDestination {
  androidDownloads,
  androidPictures,
  iosPhotos,
  webDownloads,
  temp,
  unknown,
}

class QrDownloadResult {
  QrDownloadResult({
    required this.success,
    required this.message,
    this.fileUri,
    this.destination = QrDownloadDestination.unknown,
  });

  final bool success;
  final String message;
  final String? fileUri;
  final QrDownloadDestination destination;
}

class QrDownloadService {
  QrDownloadService._();

  static final QrDownloadService instance = QrDownloadService._();

  final MethodChannel _channel = const MethodChannel(_kQrDownloadChannel);

  Uint8List? _lastSavedBytes;
  String? _lastSavedFileName;
  bool get hasSavedQr => _lastSavedBytes != null;

  String _createFileName() {
    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'farm_merchant_qr_$timestamp.png';
  }

  QrDownloadDestination _destinationFromString(String? value) {
    switch (value) {
      case 'downloads':
        return QrDownloadDestination.androidDownloads;
      case 'pictures':
        return QrDownloadDestination.androidPictures;
      case 'photos':
        return QrDownloadDestination.iosPhotos;
      case 'webDownloads':
        return QrDownloadDestination.webDownloads;
      case 'temp':
        return QrDownloadDestination.temp;
      default:
        return QrDownloadDestination.unknown;
    }
  }

  Future<QrDownloadResult> downloadQr(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final name = fileName ?? _createFileName();
    if (kIsWeb) {
      final success = await qr_web.saveFileWeb(bytes, name);
      if (success) {
        _lastSavedBytes = bytes;
        _lastSavedFileName = name;
      }
      return QrDownloadResult(
        success: success,
        message: success
            ? 'QR code downloaded successfully.'
            : 'Unable to download the QR code.',
        destination:
            success ? QrDownloadDestination.webDownloads : QrDownloadDestination.unknown,
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final response = await _channel.invokeMapMethod<String, dynamic>(
          'downloadQr',
          {
            'bytes': bytes,
            'fileName': name,
          },
        );

        final success = response?['success'] == true;
        final message = response?['message']?.toString() ??
            (success
                ? 'QR code saved successfully.'
                : 'Unable to save QR code.');
        final destination = _destinationFromString(response?['destination']?.toString());
        final fileUri = response?['fileUri']?.toString();

        if (success) {
          _lastSavedBytes = bytes;
          _lastSavedFileName = name;
        }

        return QrDownloadResult(
          success: success,
          message: message,
          fileUri: fileUri,
          destination: destination,
        );
      } on PlatformException catch (error) {
        return QrDownloadResult(
          success: false,
          message: error.message ?? 'Failed to save QR code.',
          destination: QrDownloadDestination.unknown,
        );
      }
    }

    return _saveToTemporaryDirectory(bytes, name);
  }

  Future<void> shareQr(
    Uint8List bytes, {
    String? fileName,
    String subject = 'Farm QR Code',
    String text = 'Scan this Farm QR code.',
  }) async {
    final file = await _writeTemporaryFile(
      bytes,
      fileName ?? _lastSavedFileName ?? _createFileName(),
    );
    final xfile = XFile(file.path);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: [xfile],
      ),
    );
  }

  Future<void> openSavedQr() async {
    if (_lastSavedBytes == null) {
      throw StateError('No QR code has been saved yet.');
    }
    final file = await _writeTemporaryFile(_lastSavedBytes!, _lastSavedFileName ?? _createFileName());
    final uri = Uri.file(file.path);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Unable to open saved QR code.');
    }
  }

  Future<void> deleteTemporaryFiles() async {
    final directory = await getTemporaryDirectory();
    final entries = directory.listSync();
    for (final entry in entries) {
      if (entry is File && entry.path.contains('farm_merchant_qr_')) {
        try {
          await entry.delete();
        } catch (_) {
          // Ignore deletion failures for temp cleanup.
        }
      }
    }
  }

  Future<File> _writeTemporaryFile(Uint8List bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<QrDownloadResult> _saveToTemporaryDirectory(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final file = await _writeTemporaryFile(bytes, fileName);
      _lastSavedBytes = bytes;
      _lastSavedFileName = fileName;
      return QrDownloadResult(
        success: true,
        message: 'Saved to temporary file: ${file.path}',
        fileUri: file.path,
        destination: QrDownloadDestination.temp,
      );
    } catch (error) {
      return QrDownloadResult(
        success: false,
        message: 'Failed to save QR code: ${userErrorMessage(error)}',
        destination: QrDownloadDestination.unknown,
      );
    }
  }
}
