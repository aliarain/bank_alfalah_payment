import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    PaymentLogger.enabled = false;
    PaymentLogger.sink = null;
  });

  group('PaymentLogger', () {
    test('is silent when disabled', () {
      final lines = <String>[];
      PaymentLogger.sink = lines.add;
      PaymentLogger.enabled = false;
      PaymentLogger.debug('hello');
      expect(lines, isEmpty);
    });

    test('redacts credential-like keys', () {
      expect(
        PaymentLogger.redact({
          'orderId': 'ORDER-1',
          'merchantPassword': 'hunter2',
          'AuthToken': 'abc',
          'HS_MerchantHash': 'xyz',
          'firstKey': 'k1',
          'Set-Cookie': 'session=1',
          'Authorization': 'Bearer t',
          'cardNumber': '4111111111111111',
        }),
        {
          'orderId': 'ORDER-1',
          'merchantPassword': '<redacted>',
          'AuthToken': '<redacted>',
          'HS_MerchantHash': '<redacted>',
          'firstKey': '<redacted>',
          'Set-Cookie': '<redacted>',
          'Authorization': '<redacted>',
          'cardNumber': '<redacted>',
        },
      );
    });

    test('logs safe metadata when enabled', () {
      final lines = <String>[];
      PaymentLogger.sink = lines.add;
      PaymentLogger.enabled = true;
      PaymentLogger.debug('Checkout created', metadata: {
        'orderId': 'ORDER-1',
        'token': 'secret-value',
      });
      expect(lines, hasLength(1));
      expect(lines.single, contains('ORDER-1'));
      expect(lines.single, isNot(contains('secret-value')));
    });
  });
}
