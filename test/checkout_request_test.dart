import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckoutRequest', () {
    test('requires a non-empty order ID', () {
      expect(
        () => CheckoutRequest(amount: Money.pkr(100), orderId: ''),
        throwsArgumentError,
      );
      expect(
        () => CheckoutRequest(amount: Money.pkr(100), orderId: '   '),
        throwsArgumentError,
      );
    });

    test('preserves metadata in serialization', () {
      final request = CheckoutRequest(
        amount: Money.pkr(100),
        orderId: 'ORDER-1',
        metadata: {'campaign': 'eid-sale'},
      );
      expect(request.toJson()['metadata'], {'campaign': 'eid-sale'});
    });

    test('serializes customer details', () {
      final request = CheckoutRequest(
        amount: Money.pkr(2500),
        orderId: 'ORDER-123',
        customer: const Customer(
          name: 'Ali',
          email: 'user@example.com',
          phone: '03001234567',
        ),
      );
      expect(request.toJson(), {
        'amount': {'minorUnits': 250000, 'currency': 'PKR'},
        'orderId': 'ORDER-123',
        'customer': {
          'name': 'Ali',
          'email': 'user@example.com',
          'phone': '03001234567',
        },
      });
    });

    test('omits absent optional fields', () {
      final request = CheckoutRequest(
        amount: Money.pkr(100),
        orderId: 'ORDER-1',
      );
      final json = request.toJson();
      expect(json.containsKey('customer'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });
  });

  group('CheckoutSession', () {
    test('parses backend JSON', () {
      final session = CheckoutSession.fromJson({
        'transactionId': 'TX-1',
        'checkoutUrl': 'https://gateway.example/checkout/abc',
        'returnUrl': 'https://merchant.example/return',
      });
      expect(session.transactionId, 'TX-1');
      expect(session.checkoutUri.host, 'gateway.example');
      expect(session.formFields, isNull);
    });

    test('rejects missing fields', () {
      expect(
        () => CheckoutSession.fromJson({'transactionId': 'TX-1'}),
        throwsFormatException,
      );
      expect(
        () => CheckoutSession.fromJson({
          'checkoutUrl': 'https://a.example',
          'returnUrl': 'https://b.example',
        }),
        throwsFormatException,
      );
    });

    test('rejects relative URIs', () {
      expect(
        () => CheckoutSession(
          transactionId: 'TX-1',
          checkoutUri: Uri.parse('/relative'),
          returnUri: Uri.parse('https://merchant.example/return'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('PaymentVerification', () {
    test('parses a verified response', () {
      final verification = PaymentVerification.fromJson({
        'status': 'verified',
        'transactionId': 'TX-1',
        'gatewayReference': 'REF-9',
      });
      expect(verification.status, PaymentVerificationStatus.verified);
      expect(verification.gatewayReference, 'REF-9');
    });

    test('rejects unknown status', () {
      expect(
        () => PaymentVerification.fromJson({
          'status': 'paid???',
          'transactionId': 'TX-1',
        }),
        throwsFormatException,
      );
    });

    test('rejects missing transactionId', () {
      expect(
        () => PaymentVerification.fromJson({'status': 'verified'}),
        throwsFormatException,
      );
    });
  });
}
