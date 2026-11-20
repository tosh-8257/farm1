import 'dart:io';

import 'package:farm/core/app_theme.dart';
import 'package:farm/core/crypto_coin_limit.dart';
import 'package:farm/pages/agent_payments/business_identity.dart';
import 'package:farm/pages/assistant/mkulima_limits.dart';
import 'package:farm/pages/business/ops/project_logic.dart';
import 'package:farm/services/push_session_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launcher name is FΛЯM on Android, iOS and web', () {
    const name = 'FΛЯM';
    expect(name.runes.toList(), [0x46, 0x039B, 0x042F, 0x4D]);
    final android = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final web = File('web/index.html').readAsStringSync();
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(android, contains('<string name="app_name">$name</string>'));
    expect(android, isNot(contains('FΛЯM_ΛP²')));
    expect(ios, contains('<string>$name</string>'));
    expect(web, contains('<title>$name</title>'));
    expect(manifest, contains('"$name"'));
    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId "farmapp.africa"'));
  });

  test('session policy signs out only on a real 401', () {
    expect(
      shouldForceLocalSignOut(
        statusCode: 401,
        message: 'Session not found or expired',
      ),
      isTrue,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 403,
        message: 'Session not found or expired',
      ),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 401,
        message: 'Session not found or expired',
        upload: true,
      ),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 401,
        message: 'Session not found or expired',
        biometricsOn: true,
      ),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 503,
        message: 'Session not found or expired',
        transientFailure: true,
      ),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(statusCode: 401, message: 'Unauthorized'),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 401,
        message: 'Token has been revoked',
        sessionInvalid: false,
      ),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 401,
        message: 'no',
        code: 'access_expired',
      ),
      isFalse,
    );
    expect(
      shouldForceLocalSignOut(
        statusCode: 401,
        message: 'no',
        sessionInvalid: true,
      ),
      isTrue,
    );
    expect(isTerminalSessionFailure('expired', code: 'access_expired'), isFalse);
  });

  test('coin limits follow each network and do not invent a USD minimum', () {
    final limits = parseCoinLimitList({
      'data': {
        'currency': 'usdt',
        'networks': [
          {'network': 'TRC20', 'min_amount': 1, 'max_amount': 5000},
          {'network': 'ERC20', 'min_amount': 15},
        ],
      },
    });
    expect(limitFor(limits, 'usdt'), isNull);
    final trc = limitFor(limits, 'usdt', network: 'trc20')!;
    expect(trc.minAmount, 1);
    expect(trc.maxAmount, 5000);
    expect(trc.minUsd, isNull);
    expect(trc.rangeLabel, isNot(contains('No maximum published')));
    expect(trc.rangeLabel, contains('TRC20'));
    final erc = limitFor(limits, 'USDT', network: 'ERC20')!;
    expect(erc.minAmount, 15);
    expect(erc.maxAmount, isNull);
    expect(erc.rangeLabel, contains('No maximum published'));
    expect(erc.minUsd, isNull);
    expect(erc.rangeLabel, isNot(contains('Min USD')));
    final legacy = parseCoinLimit({
      'currency': 'btc',
      'minimum_deposit_usd': 20,
    });
    expect(legacy!.minUsd, 20);
    expect(legacy.minAmount, isNull);
    final chain = parseCoinLimit({
      'currency': 'usdc',
      'network': 'algorand',
      'min_amount': null,
      'max_amount': null,
      'minimumUsd': null,
      'available': true,
    });
    expect(chain, isNotNull);
    expect(chain!.hasAnyBound, isFalse);
    expect(chain.minUsd, isNull);
    expect(chain.rangeLabel, contains('No minimum or maximum'));
    final floor = parseCoinLimit({
      'currency': 'btc',
      'minimumUsd': 2,
      'available': false,
    });
    expect(floor!.minUsd, 2);
    expect(floor.available, isFalse);
    expect(floor.rangeLabel, contains('provider floor'));
  });

  test('a website in the cover field does not replace an uploaded photo', () {
    expect(
      coverUrlForSave(
        typed: 'https://farm.example',
        uploaded: 'https://res.cloudinary.com/demo/cover.jpg',
      ),
      'https://res.cloudinary.com/demo/cover.jpg',
    );
    expect(coverUrlForSave(typed: 'https://farm.example'), isNull);
    expect(
      coverUrlForSave(typed: 'https://cdn.example/photo.png'),
      'https://cdn.example/photo.png',
    );
    expect(projectCanDiscard('draft'), isTrue);
    expect(projectCanDiscard('funded'), isFalse);
  });

  test('Mkulima does not invent a 100,000 cap', () {
    expect(mkulimaDeclaredCeiling({'daily_cap': 250000, 'per_tx_cap': 10000}), isNull);
    expect(mkulimaDeclaredCeiling({'platform_daily_ceiling': 1000000}), 1000000);
    final caps = mkulimaCeilings({
      'platform_daily_ceiling': 1000000,
      'platform_per_tx_ceiling': 1000000,
    });
    expect(caps.daily, 1000000);
    expect(caps.perTx, 1000000);
    expect(mkulimaDeclaredCeiling({}), isNull);
    const open = {
      'platform_daily_ceiling': null,
      'platform_per_tx_ceiling': null,
    };
    expect(mkulimaCeilings(open).daily, isNull);
    expect(mkulimaCeilings(open).perTx, isNull);
    expect(mkulimaCeilingLabel(open), isNull);
    expect(mkulimaAcceptsLimits(perTx: 5000000, daily: 9000000, permissions: open), isTrue);
    expect(mkulimaAcceptsLimits(perTx: 0, daily: 10, permissions: open), isFalse);
  });

  test('business lookup reads a name and a stable id', () {
    final parsed = parseBusinessIdentity({
      'data': {
        'id': '11111111-1111-1111-1111-111111111111',
        'public_code': 'FARM-204',
        'trading_name': 'Kilimo Traders',
        'status': 'approved',
      },
    })!;
    expect(parsed.name, 'Kilimo Traders');
    expect(parsed.displayId, 'FARM-204');
    expect(parsed.id, '11111111-1111-1111-1111-111111111111');
    final legacy = parseBusinessIdentity({
      'business_id': '22222222-2222-2222-2222-222222222222',
      'business_name': 'Old Shop',
    })!;
    expect(legacy.displayId, legacy.id);
    expect(legacy.name, 'Old Shop');
  });

  test('gold hairline is the existing accent and buttons stay gold', () {
    expect(AppTheme.hairline, const Color(0xFFD4AF37));
    expect(AppTheme.hairline, kBrandAccent);
    final light = AppTheme.lightTheme();
    final dark = AppTheme.darkTheme();
    expect(light.elevatedButtonTheme.style!.backgroundColor!.resolve({}), AppTheme.accent);
    expect(dark.elevatedButtonTheme.style!.backgroundColor!.resolve({}), AppTheme.accent);
    expect(light.dividerTheme.color, AppTheme.hairline);
    expect(dark.progressIndicatorTheme.color, AppTheme.hairline);
  });
}
