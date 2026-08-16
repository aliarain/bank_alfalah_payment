import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';

/// Outcomes the mock backend can simulate.
enum MockScenario {
  success('Gateway approves, backend verifies'),
  gatewayFailure('Gateway declines the payment'),
  verificationFailed('Gateway approves, backend rejects'),
  pending('Backend has no final state yet'),
  sessionError('Backend fails to create the session');

  const MockScenario(this.label);

  final String label;
}

/// A stand-in for a merchant backend so the checkout UI can be tested
/// without credentials or network access.
///
/// The "checkout page" is an auto-submitting form whose action is the
/// session's return URI carrying the simulated gateway response code —
/// the redirect parser intercepts it before any network request leaves
/// the device.
class MockSessionProvider implements BankAlfalahSessionProvider {
  MockSessionProvider({required this.scenario});

  final MockScenario scenario;

  static final _returnUri =
      Uri.parse('https://merchant.example/payments/return');

  @override
  Future<CheckoutSession> createSession(CheckoutRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (scenario == MockScenario.sessionError) {
      throw const BankAlfalahGatewayException(
          'Mock backend refused to create a session');
    }
    final responseCode = scenario == MockScenario.gatewayFailure ? '01' : '00';
    return CheckoutSession(
      transactionId: 'MOCK-TX-${request.orderId}',
      checkoutUri: _returnUri.replace(queryParameters: {
        'RC': responseCode,
        'O': request.orderId,
      }),
      returnUri: _returnUri,
      formFields: const {'mock': 'true'},
    );
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final status = switch (scenario) {
      MockScenario.verificationFailed => PaymentVerificationStatus.failed,
      MockScenario.pending => PaymentVerificationStatus.pending,
      _ => PaymentVerificationStatus.verified,
    };
    return PaymentVerification(
      status: status,
      transactionId: transactionId,
      gatewayReference: 'MOCK-REF-001',
      message: 'Simulated by MockSessionProvider (${scenario.name})',
    );
  }
}
