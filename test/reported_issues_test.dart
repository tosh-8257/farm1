import 'dart:typed_data';

import 'package:farm/pages/business/ops/project_logic.dart';
import 'package:farm/pages/business/ops/project_photos.dart';
import 'package:farm/pages/notifications/notification_feed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('tokenization submit is only at the end of a complete application', () {
    expect(
      showTokenizationSubmit(
        projectStatus: 'draft',
        applicationComplete: false,
        tokenization: const {},
      ),
      isFalse,
    );
    expect(
      showTokenizationSubmit(
        projectStatus: 'draft',
        applicationComplete: true,
        tokenization: const {'enabled': false},
      ),
      isFalse,
    );
    expect(
      showTokenizationSubmit(
        projectStatus: 'draft',
        applicationComplete: true,
        tokenization: const {'on_invest_enabled': true, 'network': 'mainnet'},
      ),
      isTrue,
    );
    expect(
      showTokenizationSubmit(
        projectStatus: 'submitted',
        applicationComplete: true,
        tokenization: const {},
      ),
      isFalse,
    );
    expect(tokenizationTitle(const {}), 'Tokenization (Algorand Mainnet)');
    expect(projectCanDiscard('draft'), isTrue);
    expect(projectCanDiscard('submitted'), isFalse);
    expect(projectLifecycleLabel('draft'), 'Draft');
    expect(projectLifecycleLabel('submitted'), 'Submitted');
    expect(projectLifecycleLabel('under_review'), 'Under review');
    expect(projectLifecycleLabel('approved'), 'Approved');
    expect(projectLifecycleLabel('listed'), 'Listed');
    expect(projectLifecycleLabel('rejected'), 'Rejected');
  });

  test('cover photos are cropped and kept under the upload limit', () {
    final source = img.Image(width: 3200, height: 800);
    img.fill(source, color: img.ColorRgb8(20, 120, 60));
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));
    final prepared = prepareProjectImage(bytes, cover: true);
    final decoded = img.decodeImage(prepared)!;
    expect(prepared.length, lessThan(5 * 1024 * 1024));
    expect(decoded.width / decoded.height, closeTo(16 / 9, 0.05));
    expect(decoded.width, lessThanOrEqualTo(1600));
  });

  test('notification feed parses nested lists and only says offline when empty', () {
    expect(
      notificationItems({
        'data': {
          'notifications': [
            {'id': '1', 'title': 'Hello'},
          ],
        },
      }).single['title'],
      'Hello',
    );
    expect(notificationLastPage({'meta': {'last_page': '2'}}, 1), 2);
    expect(
      notificationFailureMessage(Exception('SocketException: failed'), hasCache: false),
      isNot(contains('Unable to fetch')),
    );
    expect(
      notificationFailureMessage(Exception('SocketException: failed'), hasCache: true),
      isNull,
    );
  });
}
