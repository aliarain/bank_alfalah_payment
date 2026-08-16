import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('accepts a valid PKR amount', () {
      final money = Money.pkr(2500);
      expect(money.minorUnits, 250000);
      expect(money.currency, Currency.pkr);
      expect(money.formatted, '2500.00');
      expect(money.toString(), 'PKR 2500.00');
    });

    test('accepts two decimal places', () {
      expect(Money.pkr(10.50).minorUnits, 1050);
      expect(Money.pkr(0.01).minorUnits, 1);
    });

    test('rejects zero', () {
      expect(() => Money.pkr(0), throwsArgumentError);
      expect(() => Money(minorUnits: 0), throwsArgumentError);
    });

    test('rejects negative amounts', () {
      expect(() => Money.pkr(-5), throwsArgumentError);
      expect(() => Money(minorUnits: -100), throwsArgumentError);
    });

    test('rejects sub-paisa precision', () {
      expect(() => Money.pkr(10.005), throwsArgumentError);
    });

    test('rejects non-finite values', () {
      expect(() => Money.pkr(double.nan), throwsArgumentError);
      expect(() => Money.pkr(double.infinity), throwsArgumentError);
    });

    test('equality is by value', () {
      expect(Money.pkr(100), Money(minorUnits: 10000));
      expect(Money.pkr(100), isNot(Money.pkr(101)));
    });
  });
}
