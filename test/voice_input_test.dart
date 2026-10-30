import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm/pages/assistant/voice_input.dart';

void main() {
  Future<VoiceMessage?> open(WidgetTester t, {VoiceStage? stage, String? text}) async {
    VoiceMessage? out;
    var done = false;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () async {
              out = await showModalBottomSheet<VoiceMessage>(
                  context: c, builder: (_) => VoiceInputSheet(initialStage: stage, initialText: text));
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return done ? out : null;
  }

  testWidgets('transcript is editable and only sent on explicit Send', (t) async {
    VoiceMessage? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<VoiceMessage>(
                  context: c,
                  builder: (_) => const VoiceInputSheet(
                      initialStage: VoiceStage.review, initialText: 'Find a hotel in Nairobi'));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Check what we heard'), findsOneWidget);
    expect(find.textContaining('Never say your PIN'), findsOneWidget);
    expect(result, isNull);
    await t.enterText(find.byKey(const ValueKey('voice-transcript')), 'Find a cheap hotel in Nairobi');
    await t.tap(find.byKey(const ValueKey('voice-send')));
    await t.pumpAndSettle();
    expect(result?.text, 'Find a cheap hotel in Nairobi');
  });

  testWidgets('idle and error states render', (t) async {
    await open(t);
    expect(find.textContaining('Tap the mic'), findsOneWidget);
  });
}
