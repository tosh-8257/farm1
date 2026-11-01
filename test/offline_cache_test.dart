import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farm/services/offline_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.resetForTest();
  });

  test('persists per user and survives reload', () async {
    final prefs = await SharedPreferences.getInstance();
    await OfflineCache.load('u1', prefs: prefs);
    OfflineCache.write('k', {'a': 1});
    await Future<void>.delayed(Duration.zero);
    expect(OfflineCache.readMap('k'), {'a': 1});

    OfflineCache.resetForTest();
    await OfflineCache.load('u1', prefs: prefs);
    expect(OfflineCache.readMap('k'), {'a': 1});
  });

  test('another user never sees the data; clear wipes it', () async {
    final prefs = await SharedPreferences.getInstance();
    await OfflineCache.load('u1', prefs: prefs);
    OfflineCache.write('k', {'a': 1});
    await Future<void>.delayed(Duration.zero);
    await OfflineCache.load('u2', prefs: prefs);
    expect(OfflineCache.has('k'), isFalse);
    await OfflineCache.load('u1', prefs: prefs);
    await OfflineCache.clear();
    expect(OfflineCache.has('k'), isFalse);
    expect(prefs.getKeys().where((k) => k.startsWith('swr:v1:')), isEmpty);
  });
}
