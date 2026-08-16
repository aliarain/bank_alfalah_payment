import 'package:meta/meta.dart';

/// Verification outcome reported by the merchant backend.
enum PaymentVerificationStatus {
  /// The backend confirmed the transaction as paid.
  verified,

  /// The backend has not yet observed a final state.
  pending,

  /// The backend determined the transaction is not paid.
  failed,
}

/// The merchant backend's answer to "did this payment actually happen?".
@immutable
class PaymentVerification {
  /// Creates a verification result.
  const PaymentVerification({
    required this.status,
    required this.transactionId,
    this.orderId,
    this.gatewayReference,
    this.responseCode,
    this.message,
  });

  /// The verified state of the transaction.
  final PaymentVerificationStatus status;

  /// Backend-issued transaction identifier.
  final String transactionId;

  /// Merchant order identifier, when known.
  final String? orderId;

  /// Gateway-side reference, when known.
  final String? gatewayReference;

  /// Gateway response code, when known.
  final String? responseCode;

  /// Human-readable detail, when available.
  final String? message;

  /// Deserializes a verification response produced by a merchant backend.
  factory PaymentVerification.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    final status = PaymentVerificationStatus.values
        .where((s) => s.name == rawStatus)
        .firstOrNull;
    if (status == null) {
      throw FormatException(
          'PaymentVerification has unknown "status": $rawStatus', json);
    }
    final transactionId = json['transactionId'];
    if (transactionId is! String || transactionId.isEmpty) {
      throw FormatException(
          'PaymentVerification missing "transactionId"', json);
    }
    return PaymentVerification(
      status: status,
      transactionId: transactionId,
      orderId: json['orderId'] as String?,
      gatewayReference: json['gatewayReference'] as String?,
      responseCode: json['responseCode'] as String?,
      message: json['message'] as String?,
    );
  }
}
