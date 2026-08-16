import 'dart:async';

import 'package:flutter/material.dart';

import 'checkout/checkout_controller.dart';
import 'checkout/checkout_screen.dart';
import 'errors/payment_exception.dart';
import 'gateway/bank_alfalah_environment.dart';
import 'gateway/redirect_parser.dart';
import 'logging/payment_logger.dart';
import 'models/checkout_request.dart';
import 'models/checkout_session.dart';
import 'models/payment_result.dart';
import 'models/payment_verification.dart';
import 'providers/session_provider.dart';

/// Optional observability hooks for the payment lifecycle.
///
/// Hooks receive identifiers only — never gateway payloads or
/// credentials — so they are safe to forward to analytics.
class PaymentLifecycleObserver {
  /// Creates an observer; all hooks are optional.
  const PaymentLifecycleObserver({
    this.onPaymentStarted,
    this.onCheckoutOpened,
    this.onRedirectReceived,
    this.onVerificationStarted,
    this.onCompleted,
  });

  /// A checkout request was submitted to the session provider.
  final void Function(String orderId)? onPaymentStarted;

  /// The checkout UI was presented.
  final void Function(String transactionId)? onCheckoutOpened;

  /// The gateway redirected back to the return URI.
  final void Function(String transactionId)? onRedirectReceived;

  /// Backend verification began.
  final void Function(String transactionId)? onVerificationStarted;

  /// The checkout produced its single final result.
  final void Function(PaymentResult result)? onCompleted;
}

/// Client SDK for Bank Alfalah payments.
///
/// The Flutter app never talks to Bank Alfalah directly and never holds
/// merchant credentials. All gateway work happens on the merchant
/// backend behind [BankAlfalahSessionProvider]:
///
/// ```dart
/// final bankAlfalah = BankAlfalahPayment(
///   environment: BankAlfalahEnvironment.sandbox,
///   sessionProvider: MyBackendSessionProvider(),
/// );
///
/// final result = await bankAlfalah.startCheckout(
///   context: context,
///   request: CheckoutRequest(
///     amount: Money.pkr(2500),
///     orderId: 'ORDER-123',
///   ),
/// );
/// ```
class BankAlfalahPayment {
  /// Creates the SDK entry point.
  BankAlfalahPayment({
    required this.environment,
    required this.sessionProvider,
    this.observer,
    this.checkoutTimeout = const Duration(minutes: 5),
  });

  /// Which Bank Alfalah environment the backend targets.
  final BankAlfalahEnvironment environment;

  /// Bridge to the merchant backend.
  final BankAlfalahSessionProvider sessionProvider;

  /// Optional lifecycle hooks for analytics.
  final PaymentLifecycleObserver? observer;

  /// Maximum time the user gets to finish checkout.
  final Duration checkoutTimeout;

  /// Runs a complete checkout and returns exactly one [PaymentResult].
  ///
  /// Flow: create a session via the backend, present the bank-hosted
  /// checkout, strictly match the return redirect, then ask the backend
  /// to verify the transaction. A redirect alone never produces
  /// [PaymentCompleted].
  Future<PaymentResult> startCheckout({
    required BuildContext context,
    required CheckoutRequest request,
  }) async {
    observer?.onPaymentStarted?.call(request.orderId);

    final CheckoutSession session;
    try {
      session = await sessionProvider.createSession(request);
    } on BankAlfalahException catch (e) {
      return _finish(PaymentError(
        orderId: request.orderId,
        message: e.message,
        error: e,
      ));
    } catch (e) {
      return _finish(PaymentError(
        orderId: request.orderId,
        message: 'Failed to create checkout session',
        error: e,
      ));
    }

    PaymentLogger.debug('Checkout session created', metadata: {
      'orderId': request.orderId,
      'transactionId': session.transactionId,
    });

    if (!context.mounted) {
      return _finish(PaymentCancelled(
        transactionId: session.transactionId,
        orderId: request.orderId,
        message: 'Context unmounted before checkout could be presented',
      ));
    }

    final controller = CheckoutController(timeout: checkoutTimeout);
    final parser = RedirectParser(expectedReturnUri: session.returnUri);

    observer?.onCheckoutOpened?.call(session.transactionId);
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CheckoutScreen(
          session: session,
          controller: controller,
          redirectParser: parser,
        ),
      ),
    ));

    final outcome = await controller.outcome;
    final result = await _resolve(outcome, request, session);
    return _finish(result);
  }

  Future<PaymentResult> _resolve(
    CheckoutOutcome outcome,
    CheckoutRequest request,
    CheckoutSession session,
  ) async {
    switch (outcome) {
      case CheckoutCancelled():
        return PaymentCancelled(
          transactionId: session.transactionId,
          orderId: request.orderId,
        );
      case CheckoutTimedOut():
        return PaymentTimedOut(
          transactionId: session.transactionId,
          orderId: request.orderId,
          message: 'Checkout did not finish within '
              '${checkoutTimeout.inMinutes} minutes',
        );
      case CheckoutErrored(:final message, :final error):
        return PaymentError(
          transactionId: session.transactionId,
          orderId: request.orderId,
          message: message,
          error: error,
        );
      case CheckoutRedirected(:final redirect):
        observer?.onRedirectReceived?.call(session.transactionId);
        if (redirect.outcome == RedirectOutcome.failure) {
          return PaymentFailed(
            transactionId: session.transactionId,
            orderId: request.orderId,
            responseCode: redirect.responseCode,
            message: 'The gateway reported the payment as failed',
          );
        }
        return _verify(request, session);
    }
  }

  /// The redirect suggested success (or was ambiguous); only the
  /// merchant backend can confirm the payment actually happened.
  Future<PaymentResult> _verify(
    CheckoutRequest request,
    CheckoutSession session,
  ) async {
    observer?.onVerificationStarted?.call(session.transactionId);
    final PaymentVerification verification;
    try {
      verification = await sessionProvider.verifyPayment(session.transactionId);
    } catch (e) {
      // Verification could not run: the payment may or may not have
      // happened. Report pending-with-error rather than guessing.
      return PaymentError(
        transactionId: session.transactionId,
        orderId: request.orderId,
        message: 'Payment verification could not be completed; '
            'check the transaction state on your backend',
        error: e,
      );
    }

    return switch (verification.status) {
      PaymentVerificationStatus.verified => PaymentCompleted(
          transactionId: verification.transactionId,
          orderId: verification.orderId ?? request.orderId,
          gatewayReference: verification.gatewayReference,
          responseCode: verification.responseCode,
          message: verification.message,
        ),
      PaymentVerificationStatus.pending => PaymentPending(
          transactionId: verification.transactionId,
          orderId: verification.orderId ?? request.orderId,
          gatewayReference: verification.gatewayReference,
          responseCode: verification.responseCode,
          message: verification.message,
        ),
      PaymentVerificationStatus.failed => PaymentVerificationFailed(
          transactionId: verification.transactionId,
          orderId: verification.orderId ?? request.orderId,
          gatewayReference: verification.gatewayReference,
          responseCode: verification.responseCode,
          message: verification.message,
        ),
    };
  }

  PaymentResult _finish(PaymentResult result) {
    PaymentLogger.debug('Checkout finished', metadata: {
      'result': result.runtimeType.toString(),
      'transactionId': result.transactionId,
      'orderId': result.orderId,
    });
    observer?.onCompleted?.call(result);
    return result;
  }
}
