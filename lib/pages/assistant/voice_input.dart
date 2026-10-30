import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '/backend/services/api_service.dart';
import '/pages/business/ops/ops_ui.dart';

/// Result of a confirmed voice message: the text the user approved and the
/// language detected by the server. Never contains a PIN (PINs are only typed
/// in the secure PIN prompt).
class VoiceMessage {
  const VoiceMessage(this.text, this.language);
  final String text;
  final String? language;
}

const voiceMaxSeconds = 60;

/// Opens the voice sheet: record (max 60 s) -> upload -> editable transcript.
/// Returns null unless the user explicitly taps "Send".
Future<VoiceMessage?> showVoiceInputSheet(BuildContext context) =>
    showModalBottomSheet<VoiceMessage>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VoiceInputSheet(),
    );

enum VoiceStage { idle, recording, uploading, review, error }

class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({super.key, this.initialStage, this.initialText});
  final VoiceStage? initialStage; // for widget tests / screenshots only
  final String? initialText;
  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  final _rec = AudioRecorder();
  final _text = TextEditingController();
  VoiceStage _stage = VoiceStage.idle;
  String? _error;
  String? _language;
  int _secs = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage ?? VoiceStage.idle;
    _text.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<bool> _permission() async {
    if (!kIsWeb) {
      final s = await Permission.microphone.request();
      if (!s.isGranted) return false;
    }
    return _rec.hasPermission();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _secs = 0;
    });
    try {
      if (!await _permission().timeout(const Duration(seconds: 15))) {
        return _fail(
          'Microphone permission is needed. Allow it in settings, or type your message.',
        );
      }
      await _rec.start(
        kIsWeb
            ? const RecordConfig(encoder: AudioEncoder.opus, numChannels: 1)
            : const RecordConfig(
                encoder: AudioEncoder.aacLc,
                numChannels: 1,
                bitRate: 64000,
              ),
        path: kIsWeb ? '' : '${DateTime.now().millisecondsSinceEpoch}.m4a',
      ).timeout(const Duration(seconds: 15));
      setState(() => _stage = VoiceStage.recording);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _secs++);
        if (_secs >= voiceMaxSeconds) _stop();
      });
    } catch (e) {
      debugPrint('[voice] start failed: $e');
      _fail('Could not start recording on this device. You can type instead.');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    if (_stage != VoiceStage.recording) return;
    setState(() => _stage = VoiceStage.uploading);
    try {
      final path = await _rec.stop();
      if (path == null) return _fail('Nothing was recorded.');
      final bytes = await XFile(path).readAsBytes();
      final r = await ApiService.transcribeVoice(
        bytes: bytes,
        filename: kIsWeb ? 'voice.webm' : 'voice.m4a',
        mimeType: kIsWeb ? 'audio/webm' : 'audio/mp4',
      );
      final t = '${r['transcript'] ?? ''}'.trim();
      if (t.isEmpty)
        return _fail(
          'We could not hear any words. Try again closer to the mic.',
        );
      setState(() {
        _text.text = t;
        _language = r['language'] as String?;
        _stage = VoiceStage.review;
      });
    } catch (e) {
      _fail(friendlyError(e));
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _stage = VoiceStage.error;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    try {
      if (await _rec.isRecording()) await _rec.cancel();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) {
    final mm = (_secs ~/ 60).toString();
    final ss = (_secs % 60).toString().padLeft(2, '0');
    Widget body;
    switch (_stage) {
      case VoiceStage.idle:
        body = Column(
          children: [
            Text(
              'Tap the mic and speak. You can check and edit the text before it is sent.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor(c)),
            ),
            const SizedBox(height: 20),
            _MicCircle(
              icon: Icons.mic,
              onTap: _start,
              label: 'Start recording',
            ),
          ],
        );
      case VoiceStage.recording:
        body = Column(
          children: [
            Text(
              'Listening… $mm:$ss / 1:00',
              style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _secs / voiceMaxSeconds,
              color: fgColor(c),
              backgroundColor: borderColor(c),
            ),
            const SizedBox(height: 20),
            _MicCircle(icon: Icons.stop, onTap: _stop, label: 'Stop recording'),
          ],
        );
      case VoiceStage.uploading:
        body = Column(
          children: [
            CircularProgressIndicator(color: fgColor(c)),
            const SizedBox(height: 12),
            Text('Transcribing…', style: TextStyle(color: mutedColor(c))),
          ],
        );
      case VoiceStage.error:
        body = Column(
          children: [
            Icon(Icons.error_outline, color: fgColor(c), size: 36),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fgColor(c)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: secondaryButtonStyle(c),
              onPressed: _start,
              child: const Text('Try again'),
            ),
          ],
        );
      case VoiceStage.review:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Check what we heard',
              style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)),
            ),
            const SizedBox(height: 4),
            Text(
              'Edit anything that is wrong. Nothing is sent until you tap Send. Never say your PIN.',
              style: TextStyle(fontSize: 12, color: mutedColor(c)),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('voice-transcript'),
              controller: _text,
              minLines: 2,
              maxLines: 6,
              maxLength: 2000,
              style: TextStyle(color: fgColor(c)),
              decoration: bizInput(c, 'Transcript'),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _start,
                  icon: Icon(Icons.mic, color: fgColor(c), size: 18),
                  label: Text(
                    'Record again',
                    style: TextStyle(color: fgColor(c)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('voice-send'),
                    style: primaryButtonStyle(c),
                    onPressed: () {
                      final t = _text.text.trim();
                      if (t.isEmpty) return;
                      Navigator.pop(c, VoiceMessage(t, _language));
                    },
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(c).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Voice message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: fgColor(c),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancel',
                onPressed: _cancel,
                icon: Icon(Icons.close, color: fgColor(c)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _MicCircle extends StatelessWidget {
  const _MicCircle({
    required this.icon,
    required this.onTap,
    required this.label,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext c) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fgColor(c)),
        child: Icon(icon, size: 34, color: Theme.of(c).scaffoldBackgroundColor),
      ),
    ),
  );
}
