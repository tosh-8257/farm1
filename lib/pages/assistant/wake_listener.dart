import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '/backend/services/api_service.dart';
import 'hands_free.dart';
import 'voice_input.dart';

/// One foreground listen for "Hey Mkulima". Payments are not sent here.
class ForegroundWake {
  ForegroundWake({AudioRecorder? recorder}) : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;
  bool _stop = false;

  void stop() {
    _stop = true;
    unawaited(_rec.stop());
  }

  Future<void> dispose() async {
    stop();
    await _rec.dispose();
  }

  /// Records a short clip, transcribes it, and returns the command after the
  /// wake phrase. Returns null when the clip has no command or was cancelled.
  Future<VoiceMessage?> once({
    Duration maxDuration = const Duration(seconds: 12),
    Future<Map<String, dynamic>> Function(Uint8List bytes, String filename, String mime)? transcribe,
  }) async {
    _stop = false;
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw StateError('Microphone permission is needed for Hey Mkulima.');
      }
    }
    if (!await _rec.hasPermission()) {
      throw StateError('Microphone permission is needed for Hey Mkulima.');
    }
    await _rec.start(
      kIsWeb
          ? const RecordConfig(encoder: AudioEncoder.opus, numChannels: 1)
          : const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, bitRate: 64000),
      path: kIsWeb ? '' : '${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    final started = DateTime.now();
    while (!_stop && DateTime.now().difference(started) < maxDuration) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (_stop) {
      try {
        await _rec.cancel();
      } catch (_) {}
      return null;
    }
    final path = await _rec.stop();
    if (path == null || path.isEmpty) return null;
    final bytes = await XFile(path).readAsBytes();
    if (bytes.isEmpty) return null;
    final send = transcribe ??
        (Uint8List audio, String filename, String mime) => ApiService.transcribeVoice(
              bytes: audio,
              filename: filename,
              mimeType: mime,
            );
    final result = await send(
      bytes,
      kIsWeb ? 'voice.webm' : 'voice.m4a',
      kIsWeb ? 'audio/webm' : 'audio/mp4',
    );
    final transcript = '${result['transcript'] ?? ''}'.trim();
    final parsed = parseHandsFree(transcript);
    if (!parsed.hasCommand) return null;
    final command = parsed.command!.trim();
    if (voiceTextLooksLikeSecret(command)) {
      throw StateError('Say the command without your PIN. Money still needs your PIN or biometrics.');
    }
    return VoiceMessage(command, result['language'] as String?);
  }
}
