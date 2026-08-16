import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_webview_platform.dart';

void main() {
  late FakeWebViewPlatform platform;

  final returnUri = Uri.parse('https://merchant.example/payments/return');

  CheckoutSession session({Map<String, String>? formFields}) => CheckoutSession(
        transactionId: 'TX-1',
        checkoutUri: Uri.parse('https://gateway.example/checkout/abc'),
        returnUri: returnUri,
        formFields: formFields,
      );

  Future<CheckoutController> pumpScreen(
    WidgetTester tester, {
    Map<String, String>? formFields,
  }) async {
    platform = FakeWebViewPlatform.install();
    final controller = CheckoutController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CheckoutScreen(
                  session: session(formFields: formFields),
                  controller: controller,
                  redirectParser: RedirectParser(expectedReturnUri: returnUri),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return controller;
  }

  testWidgets('opens and shows a loading indicator until the page finishes',
      (tester) async {
    await pumpScreen(tester);
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(platform.lastController!.lastLoadedRequest,
        Uri.parse('https://gateway.example/checkout/abc'));

    platform.lastDelegate!.onPageFinished!('https://gateway.example/checkout');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders escaped auto-submit form when formFields are set',
      (tester) async {
    await pumpScreen(tester, formFields: {
      'amount': '100.00',
      'evil"><script>alert(1)</script>': '"><img src=x onerror=alert(1)>',
    });
    final html = platform.lastController!.lastLoadedHtml!;
    expect(html, contains('value="100.00"'));
    expect(html, isNot(contains('<script>alert(1)</script>')));
    expect(html, isNot(contains('<img src=x')));
  });

  testWidgets('matched redirect completes checkout and closes route once',
      (tester) async {
    final controller = await pumpScreen(tester);
    final decision = await platform.lastDelegate!.onNavigationRequest!(
      NavigationRequest(
        url: 'https://merchant.example/payments/return?RC=00',
        isMainFrame: true,
      ),
    );
    expect(decision, NavigationDecision.prevent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CheckoutScreen), findsNothing);
    final outcome = await controller.outcome;
    expect(outcome, isA<CheckoutRedirected>());
    expect((outcome as CheckoutRedirected).redirect.outcome,
        RedirectOutcome.success);
  });

  testWidgets('unexpected redirect stays inside the WebView', (tester) async {
    final controller = await pumpScreen(tester);
    final decision = await platform.lastDelegate!.onNavigationRequest!(
      NavigationRequest(
        url: 'https://evil.example/RC-00',
        isMainFrame: true,
      ),
    );
    expect(decision, NavigationDecision.navigate);
    await tester.pump();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(controller.isCompleted, isFalse);
  });

  testWidgets('close button asks for confirmation then cancels',
      (tester) async {
    final controller = await pumpScreen(tester);
    await tester.tap(find.byTooltip('Close checkout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cancel payment?'), findsOneWidget);

    await tester.tap(find.text('Cancel payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CheckoutScreen), findsNothing);
    expect(await controller.outcome, isA<CheckoutCancelled>());
  });

  testWidgets('declining the close confirmation keeps checkout open',
      (tester) async {
    final controller = await pumpScreen(tester);
    await tester.tap(find.byTooltip('Close checkout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(controller.isCompleted, isFalse);
  });

  testWidgets('main-frame load failure errors the checkout', (tester) async {
    final controller = await pumpScreen(tester);
    platform.lastDelegate!.onWebResourceError!(
      const FakeWebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(await controller.outcome, isA<CheckoutErrored>());
  });

  testWidgets('sub-resource failure does not abort checkout', (tester) async {
    final controller = await pumpScreen(tester);
    platform.lastDelegate!.onWebResourceError!(
      const FakeWebResourceError(
        errorCode: -2,
        description: 'analytics.js failed',
        isForMainFrame: false,
      ),
    );
    await tester.pump();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(controller.isCompleted, isFalse);
  });

  testWidgets('duplicate redirects complete exactly once', (tester) async {
    final controller = await pumpScreen(tester);
    final request = NavigationRequest(
      url: 'https://merchant.example/payments/return?RC=00',
      isMainFrame: true,
    );
    await platform.lastDelegate!.onNavigationRequest!(request);
    await platform.lastDelegate!.onNavigationRequest!(request);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CheckoutScreen), findsNothing);
    expect(await controller.outcome, isA<CheckoutRedirected>());
  });
}
