/// Base class for all exceptions thrown by this SDK.
sealed class BankAlfalahException implements Exception {
  const BankAlfalahException(this.message, {this.cause});

  /// What went wrong, safe to log (never contains credentials).
  final String message;

  /// The underlying error, when available.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// The SDK was configured incorrectly (e.g. an invalid session).
final class BankAlfalahConfigurationException extends BankAlfalahException {
  const BankAlfalahConfigurationException(super.message, {super.cause});
}

/// A network call to the merchant backend failed.
final class BankAlfalahNetworkException extends BankAlfalahException {
  const BankAlfalahNetworkException(super.message, {super.cause});
}

/// The gateway or backend returned an error while creating the session.
final class BankAlfalahGatewayException extends BankAlfalahException {
  const BankAlfalahGatewayException(super.message, {super.cause});
}

/// A gateway redirect could not be handled.
final class BankAlfalahRedirectException extends BankAlfalahException {
  const BankAlfalahRedirectException(super.message, {super.cause});
}

/// Backend verification of a transaction failed to execute.
final class BankAlfalahVerificationException extends BankAlfalahException {
  const BankAlfalahVerificationException(super.message, {super.cause});
}

/// Checkout exceeded the configured timeout.
final class BankAlfalahTimeoutException extends BankAlfalahException {
  const BankAlfalahTimeoutException(super.message, {super.cause});
}
