import 'package:farm/core/utils/activity_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hotel hold shows a readable label', () {
    final l = systemActivityLabel({
      'metadata': {'kind': 'travel_hotel', 'label': 'Hotel booking · ibis Styles'}
    })!;
    expect(l.title, 'Hotel booking · ibis Styles');
    expect(l.type, 'Hotel booking');
  });
  test('older hotel holds without a label still read well', () {
    expect(systemActivityLabel({'metadata': {'kind': 'travel_hotel'}})!.title, 'Hotel booking');
  });
  test('peer transfers keep the normal label', () {
    expect(systemActivityLabel({'metadata': null}), isNull);
    expect(systemActivityLabel({'metadata': {'kind': 'payment_link'}}), isNull);
  });
}
