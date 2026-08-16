import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_session_provider.dart';
import 'fakes/fake_webview_platform.dart';

void main() {
  late FakeWebViewPlatform platform;

  CheckoutRequest request() =>
      CheckoutRequest(amount: Money.pkr(2500), orderId: 'ORDER-1');

  /// Pumps a host app, starts a checkout, and returns its result future.
  Future<Future<PaymentResult>> startCheckout(
    WidgetTester tester,
    BankAlfalahPayment sdk,
  ) async {
    platform = FakeWebViewPlatform.install();
    late Future<PaymentResult> resultFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              resultFuture =
                  sdk.startCheckout(context: context, request: request());
            },
            child: const Text('pay'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return resultFuture;
  }

  Future<void> redirect(WidgetTester tester, String url) async {
    await platform.lastDelegate!.onNavigationRequest!(
      NavigationRequest(url: url, isMainFrame: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('full flow: create session → redirect → verify → completed',
      (tester) async {
    final provider = FakeSessionProvider();
    final events = <String>[];
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
      observer: PaymentLifecycleObserver(
        onPaymentStarted: (_) => events.add('started'),
        onCheckoutOpened: (_) => events.add('opened'),
        onRedirectReceived: (_) => events.add('redirect'),
        onVerificationStarted: (_) => events.add('verifying'),
        onCompleted: (_) => events.add('completed'),
      ),
    );

    final resultFuture = await startCheckout(tester, sdk);
    await redirect(tester, 'https://merchant.example/payments/return?RC=00');

    final result = await resultFuture;
    expect(result, isA<PaymentCompleted>());
    expect(result.transactionId, 'TX-ORDER-1');
    expect(provider.verifyCalls, 1);
    expect(provider.lastVerifiedTransactionId, 'TX-ORDER-1');
    expect(events, ['started', 'opened', 'redirect', 'verifying', 'completed']);
    expect(find.byType(CheckoutScreen), findsNothing);
  });

  testWidgets('failure redirect returns PaymentFailed without verification',
      (tester) async {
    final provider = FakeSessionProvider();
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
    );

    final resultFuture = await startCheckout(tester, sdk);
    await redirect(tester, 'https://merchant.example/payments/return?RC=01');

    final result = await resultFuture;
    expect(result, isA<PaymentFailed>());
    expect(result.responseCode, '01');
    expect(provider.verifyCalls, 0);
  });

  testWidgets('ambiguous redirect still requires verification', (tester) async {
    final provider = FakeSessionProvider(
        verificationStatus: PaymentVerificationStatus.pending);
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
    );

    final resultFuture = await startCheckout(tester, sdk);
    await redirect(tester, 'https://merchant.example/payments/return');

    expect(await resultFuture, isA<PaymentPending>());
    expect(provider.verifyCalls, 1);
  });

  testWidgets('verification rejection yields PaymentVerificationFailed',
      (tester) async {
    final provider = FakeSessionProvider(
        verificationStatus: PaymentVerificationStatus.failed);
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
    );

    final resultFuture = await startCheckout(tester, sdk);
    await redirect(tester, 'https://merchant.example/payments/return?RC=00');

    expect(await resultFuture, isA<PaymentVerificationFailed>());
  });

  testWidgets('verification exception yields PaymentError, not success',
      (tester) async {
    final provider = FakeSessionProvider(
      verifyError: const BankAlfalahNetworkException('backend unreachable'),
    );
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
    );

    final resultFuture = await startCheckout(tester, sdk);
    await redirect(tester, 'https://merchant.example/payments/return?RC=00');

    final result = await resultFuture;
    expect(result, isA<PaymentError>());
    expect((result as PaymentError).error, isA<BankAlfalahNetworkException>());
  });

  testWidgets('session creation failure yields PaymentError and no route',
      (tester) async {
    final provider = FakeSessionProvider(
      createError: const BankAlfalahGatewayException('backend said no'),
    );
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
    );

    final resultFuture = await startCheckout(tester, sdk);
    final result = await resultFuture;
    expect(result, isA<PaymentError>());
    expect(result.message, 'backend said no');
    expect(find.byType(CheckoutScreen), findsNothing);
  });

  testWidgets('timeout closes checkout and returns PaymentTimedOut',
      (tester) async {
    final provider = FakeSessionProvider();
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
      checkoutTimeout: const Duration(seconds: 2),
    );

    final resultFuture = await startCheckout(tester, sdk);
    expect(find.byType(CheckoutScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(await resultFuture, isA<PaymentTimedOut>());
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(provider.verifyCalls, 0);
  });

  testWidgets('user cancellation returns PaymentCancelled', (tester) async {
    final provider = FakeSessionProvider();
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
    );

    final resultFuture = await startCheckout(tester, sdk);
    await tester.tap(find.byTooltip('Close checkout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await resultFuture, isA<PaymentCancelled>());
    expect(provider.verifyCalls, 0);
  });

  testWidgets('duplicate redirect verifies and completes exactly once',
      (tester) async {
    final provider = FakeSessionProvider();
    var completions = 0;
    final sdk = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: provider,
      observer: PaymentLifecycleObserver(onCompleted: (_) => completions++),
    );

    final resultFuture = await startCheckout(tester, sdk);
    await platform.lastDelegate!.onNavigationRequest!(NavigationRequest(
      url: 'https://merchant.example/payments/return?RC=00',
      isMainFrame: true,
    ));
    await platform.lastDelegate!.onNavigationRequest!(NavigationRequest(
      url: 'https://merchant.example/payments/return?RC=00',
      isMainFrame: true,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await resultFuture, isA<PaymentCompleted>());
    expect(provider.verifyCalls, 1);
    expect(completions, 1);
  });
}
