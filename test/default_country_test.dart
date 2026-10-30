import 'package:farm/pages/loginpage/loginpage_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login/register default to Kenya +254', () {
    expect(kDefaultLoginCountry['iso'], 'KE');
    expect(kDefaultLoginCountry['code'], '+254');
  });
}
