import 'package:farm/pages/ecosystem/ecosystem_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing routes hide the new screens', () {
    expect(routeIsMissing(Exception('Cannot GET /api/v1/platform/status')), isTrue);
    expect(routeIsMissing(Exception('Cannot POST /api/v1/cargo/quotes')), isTrue);
    expect(routeIsMissing(Exception('fromZone should not be empty')), isFalse);
    expect(EcosystemFlags.hidden.any, isFalse);
    expect(const EcosystemFlags(cargo: true).any, isTrue);
  });

  test('integration flags come only from the status payload', () {
    const status = {
      'data': {
        'integrations': [
          {'provider': 'shopify', 'enabled': false, 'verified': false},
          {'provider': 'woocommerce', 'enabled': true, 'verified': false},
          {'provider': 'maps', 'enabled': false, 'verified': false},
        ],
      },
    };
    expect(integrationEnabled(status, 'shopify'), isFalse);
    expect(integrationEnabled(status, 'woocommerce'), isTrue);
    expect(integrationVerified(status, 'maps'), isFalse);
    expect(integrationEnabled(null, 'shopify'), isFalse);
  });

  test('cargo quotes do not invent an arrival time or a map', () {
    expect(
      cargoQuoteSummary({
        'data': {'amount': 120, 'eta': null, 'maps_verified': false},
      }),
      '120 FARM. No arrival time is published. No live map.',
    );
    expect(storeSyncMessage(verified: false), contains('unverified'));
    expect(storeSyncMessage(verified: false).toLowerCase(), contains('does not call'));
  });

  test('partner and settlement copy do not claim live tracking or a payout', () {
    expect(partnerRegistrationNote.toLowerCase(), contains('no gps'));
    expect(partnerRegistrationNote.toLowerCase(), contains('not a new account'));
    expect(settlementRecordNote.toLowerCase(), contains('does not move wallet'));
    expect(autonomousPayNote.toLowerCase(), contains('pin or biometrics'));
    expect(partnerRegistrationNote.toLowerCase(), contains('same account'));
  });

  test('catalogue, timeline, and cargo split use only server data', () {
    expect(recordList({'data': []}), isEmpty);
    expect(recordList({'data': [{'id': 'v1', 'name': 'Maize'}]}).single['name'], 'Maize');
    expect(recordList(null), isEmpty);
    expect(shipmentTimeline({'data': {'timeline': [{'status': 'booked'}]}}).single['status'], 'booked');
    expect(shipmentTimeline({'data': {}}), isEmpty);
    expect(httpsReference('https://cdn.example/pod.jpg'), isTrue);
    expect(httpsReference('http://cdn.example/pod.jpg'), isFalse);
    expect(cargoSplitValid(2000, 8000), isTrue);
    expect(cargoSplitValid(2000, 7000), isFalse);
    expect(zoneNames({'data': ['Nairobi', {'name': 'Mombasa'}]}), ['Nairobi', 'Mombasa']);
    expect(
      cargoQuoteSummary({'data': {'price_farm': 90, 'eta': null, 'maps_verified': false}}),
      '90 FARM. No arrival time is published. No live map.',
    );
    expect(const EcosystemFlags(catalogue: true, cargoList: true, partnerApply: true, cargoAdmin: true).any, isTrue);
  });
}
