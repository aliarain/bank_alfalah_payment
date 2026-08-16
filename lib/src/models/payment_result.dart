import 'package:meta/meta.dart';

/// The final outcome of a checkout.
///
/// Exactly one [PaymentResult] is produced per checkout, no matter how
/// many completion sources fire (redirect, cancel, timeout, error).
///
/// Only [PaymentCompleted] means money moved, and it is only produced
/// after the merchant backend has verified the transaction. A gateway
/// redirect alone never yields [PaymentCompleted].
@immutable
sealed class PaymentResult {
  const PaymentResult({
    this.transactionId,
    this.orderId,
    this.gatewayReference,
    this.responseCode,
    this.message,
  });

  /// Backend-issued transaction identifier, when known.
  final String? transactionId;

  /// Merchant order identifier, when known.
  final String? orderId;

  /// Gateway-side reference, when known.
  final String? gatewayReference;

  /// Gateway response code, when known.
  final String? responseCode;

  /// Human-readable detail, when available.
  final String? message;

  @override
  String toString() => '$runtimeType('
      'transactionId: $transactionId, orderId: $orderId, '
      'responseCode: $responseCode, message: $message)';
}

/// The backend verified the transaction as paid.
final class PaymentCompleted extends PaymentResult {
  const PaymentCompleted({
    required String super.transactionId,
    super.orderId,
    super.gatewayReference,
    super.responseCode,
    super.message,
  });
}

/// The gateway or backend reported the payment as failed.
final class PaymentFailed extends PaymentResult {
  const PaymentFailed({
    super.transactionId,
    super.orderId,
    super.gatewayReference,
    super.responseCode,
    super.message,
  });
}

/// The user dismissed checkout before it finished.
final class PaymentCancelled extends PaymentResult {
  const PaymentCancelled({super.transactionId, super.orderId, super.message});
}

/// Checkout finished but the backend has not yet confirmed the final
/// state. The merchant backend remains the source of truth; poll or use
/// webhooks server-side before fulfilling the order.
final class PaymentPending extends PaymentResult {
  const PaymentPending({
    super.transactionId,
    super.orderId,
    super.gatewayReference,
    super.responseCode,
    super.message,
  });
}

/// Checkout did not finish within the configured timeout.
final class PaymentTimedOut extends PaymentResult {
  const PaymentTimedOut({super.transactionId, super.orderId, super.message});
}

/// The gateway redirect suggested success but backend verification
/// rejected or could not confirm the transaction. Treat as NOT paid.
final class PaymentVerificationFailed extends PaymentResult {
  const PaymentVerificationFailed({
    super.transactionId,
    super.orderId,
    super.gatewayReference,
    super.responseCode,
    super.message,
  });
}

/// Checkout aborted due to an unexpected error (network failure,
/// WebView failure, backend error).
final class PaymentError extends PaymentResult {
  const PaymentError({
    super.transactionId,
    super.orderId,
    super.message,
    this.error,
  });

  /// The underlying error, when available.
  final Object? error;
}
