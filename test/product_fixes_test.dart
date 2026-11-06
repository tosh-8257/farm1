import 'package:farm/core/african_phone_countries.dart';
import 'package:farm/core/crypto_coin_limit.dart';
import 'package:farm/pages/assistant/hands_free.dart';
import 'package:farm/pages/business/business_kyb_logic.dart';
import 'package:farm/pages/business/ops/project_logic.dart';
import 'package:farm/pages/business/ops/team_logic.dart';
import 'package:farm/utils/personal_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration uses the same African list as login', () {
    expect(kAfricanPhoneCountries.length, greaterThan(50));
    expect(kAfricanPhoneCountries.any((c) => c['iso'] == 'KE' && c['code'] == '+254'), isTrue);
    expect(kAfricanPhoneCountries.any((c) => c['iso'] == 'NG'), isTrue);
    expect(kDefaultLoginCountry['iso'], 'KE');
    final isos = kAfricanPhoneCountries.map((c) => c['iso']).toSet();
    expect(isos.length, kAfricanPhoneCountries.length);
  });

  test('merchant QR credits stay on the personal activity list', () {
    const qr = {
      'status': 'completed',
      'transaction_type': 'merchant_payment',
      'is_outgoing': false,
      'description': 'Public QR merchant payment',
    };
    expect(isPersonalActivity(qr), isTrue);
    expect(merchantQrTitle(qr), 'Merchant QR');
    expect(
      isPersonalActivity({
        'status': 'completed',
        'transaction_type': 'merchant_payment',
        'is_outgoing': true,
      }),
      isTrue,
    );
    expect(
      isPersonalActivity({
        'status': 'completed',
        'transaction_type': 'transfer',
        'is_outgoing': false,
      }),
      isTrue,
    );
  });

  test('coin limits come only from the payload', () {
    final parsed = parseCoinLimit({
      'data': {
        'currency': 'usdc',
        'minimumAmount': 1.5,
        'maximumAmount': 20000,
        'minimumUsd': 2,
        'maximumUsd': 100000,
      },
    });
    expect(parsed!.minAmount, 1.5);
    expect(parsed.maxUsd, 100000);
    expect(parsed.allowsUsd(2), isTrue);
    expect(parsed.allowsUsd(1), isFalse);
    expect(parsed.allowsUsd(100001), isFalse);
    expect(parsed.rangeLabel, contains('USDC'));

    final list = parseCoinLimitList({
      'data': {
        'coins': {
          'btc': {'min': 0.0002, 'max': 1.5},
          'usdttrc20': {'max': 50000},
        },
      },
    });
    expect(limitFor(list, 'BTC')!.minAmount, 0.0002);
    expect(limitFor(list, 'btc')!.maxAmount, 1.5);
    expect(limitFor(list, 'usdttrc20')!.maxAmount, 50000);
    final bounds = parseCoinLimit({
      'data': {
        'currency': 'usdc',
        'min_amount': 1,
        'max_amount': 20000,
        'minimumAmount': 0.5,
        'minimumUsd': 2,
      },
    });
    expect(bounds!.minAmount, 1);
    expect(bounds.maxAmount, 20000);
    expect(bounds.minUsd, 2);
    expect(parseCoinLimit({'data': {}}), isNull);
  });

  test('Hey Mkulima extracts a command and ignores other speech', () {
    expect(parseHandsFree('hey mkulima what is my balance').command, 'what is my balance');
    expect(parseHandsFree('please check the weather').wake, isFalse);
    expect(parseHandsFree('Hey Mkulima').hasCommand, isFalse);
    expect(voiceTextLooksLikeSecret('my pin is 1234'), isTrue);
    expect(voiceTextLooksLikeSecret('send 10 to mama'), isFalse);
    expect(handsFreeLimits, contains('pocket'));
    expect(handsFreeLimits.toLowerCase(), contains('pin'));
  });

  test('team list, roles, invites and remove targets parse', () {
    final snap = parseTeamResponse({
      'data': {
        'members': [
          {'id': null, 'role': 'owner', 'user': {'full_name': 'Asha'}},
          {'id': 'm1', 'role': 'finance', 'user': {'username': 'lee'}},
        ],
        'invites': [
          {'identifier': '+254700000001', 'role': 'operations'},
        ],
      },
      'meta': {'my_role': 'owner'},
    });
    expect(snap.members, hasLength(2));
    expect(snap.invites.single['role'], 'operations');
    final listed = parseTeamResponse({
      'data': [
        {'id': null, 'role': 'owner', 'user': {'full_name': 'Asha'}},
      ],
      'invites': [
        {'id': 'inv1', 'phone': '+254700000001', 'role': 'finance', 'status': 'pending'},
      ],
      'meta': {'my_role': 'owner', 'assignable_roles': ['admin', 'finance']},
    });
    expect(listed.invites.single['phone'], '+254700000001');
    expect(teamIdentifierIsPhone('+254700000001'), isTrue);
    expect(teamIdentifierIsPhone('lee@farm.app'), isFalse);
    expect(normalizeTeamPhone('254700000001'), '+254700000001');
    expect(snap.assignableRoles, contains('admin'));
    expect(snap.assignableRoles, isNot(contains('owner')));
  });

  test('a filled project can be submitted for tokenization', () {
    expect(
      projectIsFilled({
        'project_name': 'Solar drier',
        'target_amount': 1000,
        'summary': 'Dry grain',
      }),
      isTrue,
    );
    expect(projectIsFilled({'project_name': 'X', 'target_amount': 10}), isFalse);
    expect(submitForTokenizationLabel, 'Submit for tokenization');
  });

  test('KYB submit requires Didit and does not offer a manual path', () {
    expect(kybAllowsApplicationSubmit(kybStateFor('none')), isFalse);
    expect(kybAllowsApplicationSubmit(kybStateFor('approved')), isTrue);
    expect(kybDiditRequiredMessage.toLowerCase(), contains('didit'));
    expect(kybBody(KybUiState.notStarted).toLowerCase(), contains('didit'));
  });
}
