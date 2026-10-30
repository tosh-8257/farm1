import 'package:flutter_test/flutter_test.dart';
import 'package:farm/backend/api_requests/fees_api.dart';

void main() {
  test('parses schedule and computes fees like the backend', () {
    final m = FeesApi.parse({
      'data': [
        {'key': 'withdrawal', 'label': 'Withdrawal', 'percent': 1.5, 'flat': 0, 'min': 0, 'max': 0},
        {'key': 'transfer', 'percent': '0', 'flat': 0, 'min': 0, 'max': 0},
        {'key': 'capped', 'percent': 10, 'flat': 1, 'min': 2, 'max': 5},
      ]
    });
    expect(m['withdrawal']!.feeFor(100), 1.5);
    expect(m['withdrawal']!.percentLabel, '1.5%');
    expect(m['transfer']!.feeFor(100), 0);
    expect(m['transfer']!.label, 'transfer');
    expect(m['capped']!.feeFor(5), 2); // 0.5+1 floored to min
    expect(m['capped']!.feeFor(1000), 5); // capped
    expect(m['capped']!.feeFor(0), 0);
  });
}
