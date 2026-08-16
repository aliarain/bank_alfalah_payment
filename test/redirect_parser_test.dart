import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = RedirectParser(
    expectedReturnUri: Uri.parse('https://merchant.example/payments/return'),
  );

  group('RedirectParser', () {
    test('matches a valid success redirect', () {
      final decision = parser
          .parse('https://merchant.example/payments/return?RC=00&O=ORDER-1');
      expect(decision, isA<RedirectMatched>());
      final matched = decision as RedirectMatched;
      expect(matched.outcome, RedirectOutcome.success);
      expect(matched.responseCode, '00');
      expect(matched.parameters['O'], 'ORDER-1');
    });

    test('matches a valid failure redirect', () {
      final decision =
          parser.parse('https://merchant.example/payments/return?RC=01');
      expect((decision as RedirectMatched).outcome, RedirectOutcome.failure);
    });

    test('matches with unknown outcome when RC is missing or unrecognized', () {
      final noCode = parser.parse('https://merchant.example/payments/return');
      expect((noCode as RedirectMatched).outcome, RedirectOutcome.unknown);

      final weird =
          parser.parse('https://merchant.example/payments/return?RC=99');
      expect((weird as RedirectMatched).outcome, RedirectOutcome.unknown);
    });

    test('ignores unknown hosts', () {
      expect(
        parser.parse('https://evil.example/payments/return?RC=00'),
        isA<RedirectIgnored>(),
      );
    });

    test('ignores a malicious URL containing RC-00 in the path', () {
      expect(
        parser.parse('https://evil.example/RC-00'),
        isA<RedirectIgnored>(),
      );
      expect(
        parser.parse('https://evil.example/phish?page=RC-00'),
        isA<RedirectIgnored>(),
      );
    });

    test('ignores misleading query strings on the wrong path', () {
      expect(
        parser.parse('https://merchant.example/other?RC=00'),
        isA<RedirectIgnored>(),
      );
    });

    test('ignores scheme downgrades', () {
      expect(
        parser.parse('http://merchant.example/payments/return?RC=00'),
        isA<RedirectIgnored>(),
      );
    });

    test('ignores different ports', () {
      expect(
        parser.parse('https://merchant.example:8443/payments/return?RC=00'),
        isA<RedirectIgnored>(),
      );
    });

    test('ignores malformed URIs', () {
      expect(parser.parse('::not a uri::'), isA<RedirectIgnored>());
      expect(parser.parse(''), isA<RedirectIgnored>());
      expect(parser.parse('about:blank'), isA<RedirectIgnored>());
    });

    test('host matching is case-insensitive, trailing slash tolerated', () {
      expect(
        parser.parse('https://MERCHANT.example/payments/return/?RC=00'),
        isA<RedirectMatched>(),
      );
    });

    test('never matches a host that merely ends with the expected host', () {
      expect(
        parser.parse('https://notmerchant.example/payments/return?RC=00'),
        isA<RedirectIgnored>(),
      );
    });
  });
}
