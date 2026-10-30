import 'package:farm/pages/travel/hotel_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hotelTitle shows hotel name when present', () {
    expect(
      hotelTitle({'hotel_name': 'ibis Styles - Nairobi, Westlands', 'checkin': '2026-11-13', 'checkout': '2026-11-15'}),
      'ibis Styles - Nairobi, Westlands · 2026-11-13 → 2026-11-15',
    );
  });
  test('hotelTitle falls back for older bookings without a name', () {
    expect(hotelTitle({'checkin': '2026-11-13', 'checkout': '2026-11-15'}), 'Hotel · 2026-11-13 → 2026-11-15');
  });
  test('non-refundable rate without penalty rows is not shown as free cancellation', () {
    expect(cancellationText(const [], false), 'Non-refundable');
    expect(cancellationText(const [], true), 'Free cancellation');
    expect(cancellationText(const [{'cancel_time': '2026-11-12', 'currency': 'USD', 'amount': 57.27}], true),
        'From 2026-11-12: USD 57.27');
  });
  test('cancel is hidden for non-refundable or unconfirmed bookings', () {
    expect(canCancelHotel({'status': 'confirmed', 'summary': {'refundable': true}}), isTrue);
    expect(canCancelHotel({'status': 'confirmed', 'summary': {'refundable': false}}), isFalse);
    expect(canCancelHotel({'status': 'cancelled', 'summary': {'refundable': true}}), isFalse);
  });
}
