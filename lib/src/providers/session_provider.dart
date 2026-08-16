import '../models/checkout_request.dart';
import '../models/checkout_session.dart';
import '../models/payment_verification.dart';

/// The contract between this SDK and the merchant backend.
///
/// Implementations call the merchant's own API — typically
/// `POST /payments/create` and `GET /payments/{id}/verify` — which is the
/// only place Bank Alfalah credentials may live. The Flutter app never
/// holds merchant passwords, hashes, or encryption keys.
///
/// ```dart
/// class MyBackendSessionProvider implements BankAlfalahSessionProvider {
///   @override
///   Future<CheckoutSession> createSession(CheckoutRequest request) async {
///     final response = await api.post('/payments/create', request.toJson());
///     return CheckoutSession.fromJson(response);
///   }
///
///   @override
///   Future<PaymentVerification> verifyPayment(String transactionId) async {
///     final response = await api.get('/payments/$transactionId/verify');
///     return PaymentVerification.fromJson(response);
///   }
/// }
/// ```
abstract interface class BankAlfalahSessionProvider {
  /// Asks the merchant backend to create a gateway transaction and
  /// return a [CheckoutSession] the client can present.
  Future<CheckoutSession> createSession(CheckoutRequest request);

  /// Asks the merchant backend to verify the transaction's final state
  /// server-side. Called after checkout finishes; a redirect alone is
  /// never trusted as proof of payment.
  Future<PaymentVerification> verifyPayment(String transactionId);
}
