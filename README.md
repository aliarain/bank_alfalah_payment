# bank_alfalah_payment

A Flutter client SDK for accepting Bank Alfalah payments. It presents
the bank-hosted checkout in a WebView, strictly validates the gateway's
return redirect, and reports a single typed `PaymentResult` — while your
backend owns credentials, session creation, and payment verification.

> **Beta.** `0.1.0-beta.x` is a security-driven rewrite. Validate the
> flow against the current Bank Alfalah sandbox before going live.

## ⚠️ Security warning

**Never place Bank Alfalah merchant credentials inside your Flutter
application.** Merchant IDs, passwords, hashes, and encryption keys
belong on your server. Anything shipped in an app binary can be
extracted. This SDK is designed so it never needs them.

## Architecture

```text
Flutter app  →  Your backend  →  Bank Alfalah
```

1. Flutter asks **your backend** to create a payment session.
2. Your backend (holding the credentials) creates the gateway
   transaction and returns a checkout URL + return URL.
3. Flutter opens the bank-hosted checkout in a WebView.
4. The gateway redirects to the return URL when checkout finishes.
5. Flutter asks your backend to **verify** the transaction server-side.
6. Only a backend-verified payment is reported as `PaymentCompleted`.

A WebView redirect is never treated as proof of payment.

## Installation

```yaml
dependencies:
  bank_alfalah_payment: ^0.1.0-beta.1
```

## Quick start

```dart
final bankAlfalah = BankAlfalahPayment(
  environment: BankAlfalahEnvironment.sandbox,
  sessionProvider: MyBackendSessionProvider(), // talks to YOUR server
);

final result = await bankAlfalah.startCheckout(
  context: context,
  request: CheckoutRequest(
    amount: Money.pkr(2500),
    orderId: 'ORDER-123',
    customer: Customer(email: 'user@example.com', phone: '03001234567'),
  ),
);

switch (result) {
  case PaymentCompleted():          // verified paid — fulfill the order
  case PaymentPending():            // wait for backend/webhook confirmation
  case PaymentFailed():             // gateway declined
  case PaymentCancelled():          // user closed checkout
  case PaymentTimedOut():           // checkout took too long
  case PaymentVerificationFailed(): // redirect said OK, backend said no
  case PaymentError():              // network / WebView / backend error
}
```

## Backend contract

Implement `BankAlfalahSessionProvider` against two endpoints on your
server:

```dart
abstract interface class BankAlfalahSessionProvider {
  Future<CheckoutSession> createSession(CheckoutRequest request);
  Future<PaymentVerification> verifyPayment(String transactionId);
}
```

**`POST /payments/create`** — receives `CheckoutRequest.toJson()`,
creates the Bank Alfalah transaction (hashing, credentials, and gateway
calls happen here), and responds with:

```json
{
  "transactionId": "TX-123",
  "checkoutUrl": "https://payments.bankalfalah.com/...",
  "returnUrl": "https://yourserver.example/payments/return",
  "formFields": { "optional": "POST form hand-off fields" }
}
```

**`GET /payments/{transactionId}/verify`** — checks the transaction
state with Bank Alfalah server-to-server and responds with:

```json
{
  "status": "verified | pending | failed",
  "transactionId": "TX-123",
  "orderId": "ORDER-123",
  "gatewayReference": "...",
  "responseCode": "00",
  "message": "..."
}
```

`CheckoutSession.fromJson` / `PaymentVerification.fromJson` parse these
shapes directly. Redirects to any URL other than `returnUrl` (matched on
scheme, host, port, and path) are ignored and never affect payment
state.

## Sandbox

Set `environment: BankAlfalahEnvironment.sandbox` and point your backend
at the Bank Alfalah sandbox gateway. Gateway endpoints are chosen by
your backend, never hardcoded in the app. The bundled
[example app](example/) includes a `MockSessionProvider` so you can
exercise every UI state with no credentials at all.

## Error handling

All SDK failures are typed:

| Exception | Meaning |
| --- | --- |
| `BankAlfalahConfigurationException` | Invalid SDK/session configuration |
| `BankAlfalahNetworkException` | Backend call failed |
| `BankAlfalahGatewayException` | Gateway/backend rejected the operation |
| `BankAlfalahRedirectException` | Redirect could not be handled |
| `BankAlfalahVerificationException` | Verification could not run |
| `BankAlfalahTimeoutException` | Checkout timed out |

Exceptions thrown by your `BankAlfalahSessionProvider` are surfaced as a
`PaymentError` result — `startCheckout` always resolves with exactly one
`PaymentResult`.

Optional observability (identifiers only, never payloads):

```dart
observer: PaymentLifecycleObserver(
  onPaymentStarted: ..., onCheckoutOpened: ...,
  onRedirectReceived: ..., onVerificationStarted: ..., onCompleted: ...,
)
```

## Production checklist

- [ ] No Bank Alfalah credentials anywhere in the Flutter app or repo.
- [ ] `createSession` and `verifyPayment` implemented on your backend.
- [ ] Orders are fulfilled only on `PaymentCompleted` (or a
      server-side webhook), never on a redirect alone.
- [ ] Return URL uses HTTPS and is registered with Bank Alfalah.
- [ ] Flow manually verified against the current Bank Alfalah sandbox.
- [ ] `PaymentLogger.enabled` is `false` in release builds.
- [ ] `PaymentPending` handled (poll your backend / webhook).

## Contributing

Issues and PRs are welcome at
[github.com/aliarain/bank_alfalah_payment](https://github.com/aliarain/bank_alfalah_payment).
Run `dart format .`, `flutter analyze`, and `flutter test` before
submitting. Upgrading from `0.0.1`? See [MIGRATION.md](MIGRATION.md).
