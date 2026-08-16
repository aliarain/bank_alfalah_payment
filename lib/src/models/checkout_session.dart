import 'package:meta/meta.dart';

/// A checkout session created by the merchant backend.
///
/// The backend holds all Bank Alfalah credentials, creates the gateway
/// transaction, and returns only what the client needs: where to send the
/// user ([checkoutUri]) and how to recognize the gateway's redirect back
/// ([returnUri]).
@immutable
class CheckoutSession {
  /// Creates a checkout session.
  ///
  /// Both [checkoutUri] and [returnUri] must be absolute URIs.
  CheckoutSession({
    required this.transactionId,
    required this.checkoutUri,
    required this.returnUri,
    this.formFields,
  }) {
    if (!checkoutUri.isAbsolute) {
      throw ArgumentError.value(
          checkoutUri, 'checkoutUri', 'must be an absolute URI');
    }
    if (!returnUri.isAbsolute) {
      throw ArgumentError.value(
          returnUri, 'returnUri', 'must be an absolute URI');
    }
  }

  /// Backend-issued identifier used later to verify the payment.
  final String transactionId;

  /// Where the WebView is sent to present the bank-hosted checkout.
  ///
  /// When [formFields] is null this URI is loaded directly (preferred).
  /// When [formFields] is provided, an auto-submitting HTML form POSTs
  /// these fields to this URI instead.
  final Uri checkoutUri;

  /// The redirect URI the gateway will send the user back to when
  /// checkout finishes. Redirects are matched strictly against its
  /// scheme, host, port, and path — never by URL substring.
  final Uri returnUri;

  /// Optional form fields for backends that only support POST-form
  /// hand-off. Values are HTML-escaped before rendering. Prefer
  /// returning a ready [checkoutUri] from the backend when the gateway
  /// supports it.
  final Map<String, String>? formFields;

  /// Deserializes a session produced by a merchant backend.
  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    final transactionId = json['transactionId'];
    final checkoutUrl = json['checkoutUrl'];
    final returnUrl = json['returnUrl'];
    if (transactionId is! String || transactionId.isEmpty) {
      throw FormatException('CheckoutSession missing "transactionId"', json);
    }
    if (checkoutUrl is! String) {
      throw FormatException('CheckoutSession missing "checkoutUrl"', json);
    }
    if (returnUrl is! String) {
      throw FormatException('CheckoutSession missing "returnUrl"', json);
    }
    final fields = json['formFields'];
    return CheckoutSession(
      transactionId: transactionId,
      checkoutUri: Uri.parse(checkoutUrl),
      returnUri: Uri.parse(returnUrl),
      formFields: fields is Map
          ? fields.map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
    );
  }
}
