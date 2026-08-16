import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

RedirectMatched _redirect(RedirectOutcome outcome) =>
    RedirectMatched(outcome: outcome, parameters: const {}, responseCode: '00');

void main() {
  group('CheckoutController exactly-once completion', () {
    test('success redirect fires once', () async {
      final controller = CheckoutController();
      expect(
          controller
              .complete(CheckoutRedirected(_redirect(RedirectOutcome.success))),
          isTrue);
      expect(
          controller
              .complete(CheckoutRedirected(_redirect(RedirectOutcome.success))),
          isFalse);
      expect(await controller.outcome, isA<CheckoutRedirected>());
    });

    test('failure redirect fires once', () async {
      final controller = CheckoutController();
      expect(
          controller
              .complete(CheckoutRedirected(_redirect(RedirectOutcome.failure))),
          isTrue);
      expect(controller.complete(const CheckoutCancelled()), isFalse);
      expect(await controller.outcome, isA<CheckoutRedirected>());
    });

    test('cancel fires once', () async {
      final controller = CheckoutController();
      expect(controller.complete(const CheckoutCancelled()), isTrue);
      expect(controller.complete(const CheckoutCancelled()), isFalse);
      expect(await controller.outcome, isA<CheckoutCancelled>());
    });

    test('timeout fires once', () {
      fakeAsync((async) {
        final controller =
            CheckoutController(timeout: const Duration(minutes: 5));
        controller.start();
        CheckoutOutcome? outcome;
        controller.outcome.then((o) => outcome = o);

        async.elapse(const Duration(minutes: 5, seconds: 1));
        expect(outcome, isA<CheckoutTimedOut>());

        // A late redirect must not override the timeout.
        expect(
            controller.complete(
                CheckoutRedirected(_redirect(RedirectOutcome.success))),
            isFalse);
      });
    });

    test('redirect then timeout still fires once', () {
      fakeAsync((async) {
        final controller =
            CheckoutController(timeout: const Duration(minutes: 5));
        controller.start();
        final outcomes = <CheckoutOutcome>[];
        controller.outcome.then(outcomes.add);

        controller
            .complete(CheckoutRedirected(_redirect(RedirectOutcome.success)));
        // Elapse far beyond the timeout: the cancelled timer must not fire.
        async.elapse(const Duration(minutes: 30));

        expect(outcomes, hasLength(1));
        expect(outcomes.single, isA<CheckoutRedirected>());
      });
    });

    test('close then redirect still fires once', () async {
      final controller = CheckoutController();
      controller.complete(const CheckoutCancelled());
      controller
          .complete(CheckoutRedirected(_redirect(RedirectOutcome.success)));
      expect(await controller.outcome, isA<CheckoutCancelled>());
    });

    test('dispose resolves an unfinished checkout as cancelled', () async {
      final controller = CheckoutController();
      controller.start();
      controller.dispose();
      expect(await controller.outcome, isA<CheckoutCancelled>());
    });

    test('dispose after completion preserves the original outcome', () async {
      final controller = CheckoutController();
      controller.complete(const CheckoutTimedOut());
      controller.dispose();
      expect(await controller.outcome, isA<CheckoutTimedOut>());
    });

    test('start is idempotent and does not reset the timer', () {
      fakeAsync((async) {
        final controller =
            CheckoutController(timeout: const Duration(minutes: 5));
        controller.start();
        async.elapse(const Duration(minutes: 4));
        controller.start();
        async.elapse(const Duration(minutes: 1, seconds: 1));
        expect(controller.isCompleted, isTrue);
      });
    });
  });
}
