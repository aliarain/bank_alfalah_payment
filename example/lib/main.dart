import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';
import 'package:flutter/material.dart';

import 'mock_session_provider.dart';

/// Demonstrates the full checkout flow against a mock backend, so the
/// UI can be exercised without Bank Alfalah credentials.
///
/// In a real app, replace [MockSessionProvider] with an implementation
/// that calls YOUR backend. Never place Bank Alfalah merchant
/// credentials inside a Flutter application.
void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Alfalah Payment Example',
      theme: ThemeData(colorSchemeSeed: Colors.red),
      home: const CheckoutDemoPage(),
    );
  }
}

class CheckoutDemoPage extends StatefulWidget {
  const CheckoutDemoPage({super.key});

  @override
  State<CheckoutDemoPage> createState() => _CheckoutDemoPageState();
}

class _CheckoutDemoPageState extends State<CheckoutDemoPage> {
  /// Which outcome the mock backend should simulate.
  MockScenario _scenario = MockScenario.success;
  PaymentResult? _lastResult;
  bool _busy = false;

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _lastResult = null;
    });

    final bankAlfalah = BankAlfalahPayment(
      environment: BankAlfalahEnvironment.sandbox,
      sessionProvider: MockSessionProvider(scenario: _scenario),
      observer: PaymentLifecycleObserver(
        onPaymentStarted: (orderId) => debugPrint('started: $orderId'),
        onRedirectReceived: (txId) => debugPrint('redirect: $txId'),
        onVerificationStarted: (txId) => debugPrint('verifying: $txId'),
      ),
    );

    final result = await bankAlfalah.startCheckout(
      context: context,
      request: CheckoutRequest(
        amount: Money.pkr(2500),
        orderId: 'ORDER-${DateTime.now().millisecondsSinceEpoch}',
        customer: const Customer(
          email: 'user@example.com',
          phone: '03001234567',
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Alfalah Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'This example runs against a mock backend. '
            'Pick a scenario and start a checkout.',
          ),
          const SizedBox(height: 16),
          for (final scenario in MockScenario.values)
            ListTile(
              title: Text(scenario.label),
              selected: _scenario == scenario,
              trailing: _scenario == scenario
                  ? const Icon(Icons.check_circle)
                  : const Icon(Icons.circle_outlined),
              onTap: _busy ? null : () => setState(() => _scenario = scenario),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _pay,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Pay PKR 2,500.00'),
          ),
          const SizedBox(height: 24),
          if (_lastResult != null) _ResultCard(result: _lastResult!),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final PaymentResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (result) {
      PaymentCompleted() => (Icons.check_circle, Colors.green, 'Completed'),
      PaymentPending() => (Icons.hourglass_top, Colors.orange, 'Pending'),
      PaymentFailed() => (Icons.cancel, Colors.red, 'Failed'),
      PaymentVerificationFailed() => (
          Icons.gpp_bad,
          Colors.red,
          'Verification failed'
        ),
      PaymentCancelled() => (Icons.close, Colors.grey, 'Cancelled'),
      PaymentTimedOut() => (Icons.timer_off, Colors.grey, 'Timed out'),
      PaymentError() => (Icons.error, Colors.red, 'Error'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: Text(
          [
            if (result.transactionId != null) 'tx: ${result.transactionId}',
            if (result.orderId != null) 'order: ${result.orderId}',
            if (result.message != null) result.message!,
          ].join('\n'),
        ),
      ),
    );
  }
}
