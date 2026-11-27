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

  test('module list replaces route probes and fees stay server-side', () {
    final flags = flagsFromModules({
      'data': {
        'modules': [
          {'id': 'dropshipping_lite', 'enabled': true},
          {'id': 'cargo_quotes', 'enabled': true},
          {'id': 'cargo_admin', 'enabled': false},
          {'id': 'shopify', 'enabled': false},
        ],
        'integrations': [
          {'provider': 'shopify', 'enabled': false, 'verified': false},
        ],
      },
    });
    expect(flags.dropship, isTrue);
    expect(flags.catalogue, isTrue);
    expect(flags.cargo, isTrue);
    expect(flags.escrowPay, isTrue);
    expect(flags.cargoAdmin, isFalse);
    expect(flags.stores, isFalse);
    expect(moduleList({'data': {}}), isNull);
    final lines = orderFeeLines({
      'retail_total': 100,
      'supplier_total': 40,
      'commission_farm': null,
    });
    expect(lines.map((line) => line.value), contains('Not configured'));
    expect(lines.map((line) => line.label), isNot(contains('Seller net')));
    expect(feeSummary(cargoFeeLines({'price_farm': 25, 'eta': null, 'maps_verified': false})), contains('25'));
    expect(feeSummary(cargoFeeLines({'price_farm': 25, 'eta': null, 'maps_verified': false})), contains('None published'));
    final totals = salesTotals([
      {'retail_total': 10, 'supplier_total': 4, 'commission_farm': 1},
      {'retail_total': 5, 'supplier_total': 2, 'commission_farm': null},
    ]);
    expect(totals.retail, 15);
    expect(totals.commission, isNull);
    expect(totals.net, isNull);
    expect(ecosystemNoticeGroup({'title': 'Shipment update', 'type': 'system'}), 'shipment');
    expect(ecosystemNoticeGroup({'title': 'Order update'}), 'order');
    expect(ecosystemNoticeGroup({'title': 'Delivery job'}), 'job');
    expect(ecosystemNoticeGroup({'title': 'Delivery code'}), 'delivery_code');
    expect(flagsFromModules({
      'data': {
        'modules': [
          {'id': 'escrow_payments', 'enabled': true},
          {'id': 'partner_applications', 'enabled': true},
        ],
      },
    }).partnerPortal, isTrue);
  });

  test('escrow and partner bodies match the backend contract', () {
    final pay = orderPayBody({'pin': '1234', 'idempotencyKey': 'should-not-send'});
    expect(pay, {'pin': '1234'});
    expect(pay.containsKey('transactionId'), isFalse);
    expect(pay.containsKey('idempotencyKey'), isFalse);
    final book = cargoBookBody(
      fromZone: 'A',
      toZone: 'B',
      weightKg: 2,
      idempotencyKey: 'cargo-key-1',
      auth: {'biometric_auth': true, 'device_fingerprint': 'dev'},
    );
    expect(book['idempotencyKey'], 'cargo-key-1');
    expect(book['biometric_auth'], isTrue);
    expect(book.containsKey('transactionId'), isFalse);
    expect(shipmentEventBody('cancelled'), {'status': 'cancelled'});
    expect(partnerDecisionBody('rejected'), {'decision': 'rejected'});
    expect(partnerOnlineBody(true), {'online': true});
    expect(partnerLocationBody(1.2, 36.8), {'lat': 1.2, 'lng': 36.8});
    expect(partnerDocumentBody('licence', expiresAt: '2027-01-01'), {'kind': 'licence', 'expiresAt': '2027-01-01'});
    expect(partnerMayPostLocation(online: true, assigned: true), isTrue);
    expect(partnerMayPostLocation(online: true, assigned: false), isFalse);
    expect(partnerMayPostLocation(online: false, assigned: true), isFalse);
    expect(assignmentJobId({'id': 'assignment', 'job_id': 'job-1'}), 'job-1');
    final shown = withoutDeliverySecret({
      'data': {'method': 'otp', 'otp': '123456', 'sent_to_recipient': true},
    });
    expect(shown['data'], isNot(contains('otp')));
    expect((shown['data'] as Map)['sent_to_recipient'], isTrue);
    expect(noticeEntityId({'entityId': 'job-9'}), 'job-9');
  });
}
