import 'package:meta/meta.dart';

import 'customer.dart';
import 'money.dart';

/// The details a merchant app supplies to start a checkout.
///
/// This object is handed to the app's [BankAlfalahSessionProvider], which
/// forwards it to the merchant backend. The backend — never the Flutter
/// app — talks to Bank Alfalah and creates the actual gateway transaction.
@immutable
class CheckoutRequest {
  /// Creates a checkout request.
  ///
  /// [orderId] must be a non-empty merchant-side order identifier.
  CheckoutRequest({
    required this.amount,
    required this.orderId,
    this.customer,
    this.metadata = const {},
  }) {
    if (orderId.trim().isEmpty) {
      throw ArgumentError.value(
          orderId, 'orderId', 'orderId must not be empty');
    }
  }

  /// The validated amount to charge.
  final Money amount;

  /// Merchant order identifier for this payment.
  final String orderId;

  /// Optional customer details.
  final Customer? customer;

  /// Optional extra key/value data forwarded to the backend untouched.
  final Map<String, String> metadata;

  /// Serializes the request for transmission to a merchant backend.
  Map<String, Object> toJson() => {
        'amount': {
          'minorUnits': amount.minorUnits,
          'currency': amount.currency.code,
        },
        'orderId': orderId,
        if (customer != null) 'customer': customer!.toJson(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
