import 'dart:async';

import 'package:meta/meta.dart';

import '../gateway/redirect_parser.dart';

/// How a checkout session ended, before backend verification.
///
/// This is internal plumbing between the checkout UI and
/// [BankAlfalahPayment]; merchant apps receive a `PaymentResult` instead.
@immutable
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

/// The gateway redirected back to the session's return URI.
final class CheckoutRedirected extends CheckoutOutcome {
  const CheckoutRedirected(this.redirect);

  /// The strictly matched redirect.
  final RedirectMatched redirect;
}

/// The user closed checkout before it finished.
final class CheckoutCancelled extends CheckoutOutcome {
  const CheckoutCancelled();
}

/// Checkout did not finish within the configured timeout.
final class CheckoutTimedOut extends CheckoutOutcome {
  const CheckoutTimedOut();
}

/// Checkout aborted because the WebView failed.
final class CheckoutErrored extends CheckoutOutcome {
  const CheckoutErrored(this.message, {this.error});

  /// Description of the failure, safe to log.
  final String message;

  /// The underlying error, when available.
  final Object? error;
}

/// Owns the lifecycle of one checkout attempt.
///
/// Guarantees that of all possible completion sources — success
/// redirect, failure redirect, close button, timeout, WebView error,
/// route dismissal — exactly one wins. Later completions are ignored.
class CheckoutController {
  /// Creates a controller with a cancellable [timeout] (default 5 minutes).
  CheckoutController({this.timeout = const Duration(minutes: 5)});

  /// Maximum time the user gets to finish checkout.
  final Duration timeout;

  final _completer = Completer<CheckoutOutcome>();
  Timer? _timer;

  /// Resolves with the single outcome of this checkout.
  Future<CheckoutOutcome> get outcome => _completer.future;

  /// Whether an outcome has already been recorded.
  bool get isCompleted => _completer.isCompleted;

  /// Starts the timeout clock. Safe to call once.
  void start() {
    if (isCompleted) return;
    _timer ??= Timer(timeout, () => complete(const CheckoutTimedOut()));
  }

  /// Records [outcome] if no outcome has been recorded yet.
  ///
  /// Returns true when this call won; false when a previous completion
  /// already decided the checkout.
  bool complete(CheckoutOutcome outcome) {
    if (_completer.isCompleted) return false;
    _timer?.cancel();
    _timer = null;
    _completer.complete(outcome);
    return true;
  }

  /// Cancels the timeout. If the checkout has no outcome yet, records
  /// [CheckoutCancelled] so a dismissed route still resolves the future.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (!_completer.isCompleted) {
      _completer.complete(const CheckoutCancelled());
    }
  }
}
