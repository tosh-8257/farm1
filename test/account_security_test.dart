import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm/pages/security/account_security_logic.dart';
import 'package:farm/pages/security/change_password_page.dart';

void main() {
  group('passwordPolicyError', () {
    test('matches the backend policy', () {
      expect(passwordPolicyError('Short1!'), isNotNull);
      expect(passwordPolicyError('alllowercase1!x'), isNotNull);
      expect(passwordPolicyError('ALLUPPERCASE1!X'), isNotNull);
      expect(passwordPolicyError('NoDigitsHere!!'), isNotNull);
      expect(passwordPolicyError('NoSymbols12345'), isNotNull);
      expect(passwordPolicyError('Valid-Passw0rd'), isNull);
    });
  });

  group('changePasswordFormError', () {
    test('requires current, matching and different passwords', () {
      expect(changePasswordFormError(current: '', next: 'Valid-Passw0rd', confirm: 'Valid-Passw0rd'), isNotNull);
      expect(changePasswordFormError(current: 'x', next: 'Valid-Passw0rd', confirm: 'Other-Passw0rd'), isNotNull);
      expect(changePasswordFormError(current: 'Valid-Passw0rd', next: 'Valid-Passw0rd', confirm: 'Valid-Passw0rd'), isNotNull);
      expect(changePasswordFormError(current: 'Old-Passw0rd!', next: 'Valid-Passw0rd', confirm: 'Valid-Passw0rd'), isNull);
    });
  });

  group('extractVerificationToken', () {
    final t = 'a' * 64;
    test('reads links, raw tokens and rejects junk', () {
      expect(extractVerificationToken('https://app.example/verify-email?token=$t'), t);
      expect(extractVerificationToken(t.toUpperCase()), t);
      expect(extractVerificationToken('https://x/verify-email/$t'), t);
      expect(extractVerificationToken('not-a-token'), isNull);
      expect(extractVerificationToken(''), isNull);
    });
  });

  test('friendlyAuthError maps provider-not-configured and rate limits', () {
    expect(friendlyAuthError(503, 'x'), contains('not set up'));
    expect(friendlyAuthError(429, 'x'), contains('Too many'));
    expect(friendlyAuthError(500, 'fallback'), 'fallback');
  });

  testWidgets('change password shows a validation error state without calling the server', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChangePasswordPage()));
    await tester.enterText(find.byKey(const Key('cp-current')), 'Old-Passw0rd!');
    await tester.enterText(find.byKey(const Key('cp-new')), 'weak');
    await tester.enterText(find.byKey(const Key('cp-confirm')), 'weak');
    await tester.tap(find.byKey(const Key('cp-submit')));
    await tester.pump();
    expect(find.byKey(const Key('cp-error')), findsOneWidget);
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
  });
}
