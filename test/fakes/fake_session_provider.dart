import 'package:bank_alfalah_payment/bank_alfalah_payment.dart';

/// Scriptable in-memory backend for tests.
class FakeSessionProvider implements BankAlfalahSessionProvider {
  FakeSessionProvider({
    this.createError,
    this.verifyError,
    this.verificationStatus = PaymentVerificationStatus.verified,
    Uri? returnUri,
  }) : returnUri =
            returnUri ?? Uri.parse('https://merchant.example/payments/return');

  final Object? createError;
  final Object? verifyError;
  final PaymentVerificationStatus verificationStatus;
  final Uri returnUri;

  int createCalls = 0;
  int verifyCalls = 0;
  String? lastVerifiedTransactionId;

  @override
  Future<CheckoutSession> createSession(CheckoutRequest request) async {
    createCalls++;
    if (createError != null) throw createError!;
    return CheckoutSession(
      transactionId: 'TX-${request.orderId}',
      checkoutUri: Uri.parse('https://gateway.example/checkout/abc'),
      returnUri: returnUri,
    );
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionId) async {
    verifyCalls++;
    lastVerifiedTransactionId = transactionId;
    if (verifyError != null) throw verifyError!;
    return PaymentVerification(
      status: verificationStatus,
      transactionId: transactionId,
      orderId: 'ORDER-1',
      gatewayReference: 'REF-1',
      responseCode: '00',
    );
  }
}
