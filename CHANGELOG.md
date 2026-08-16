# Changelog

## 0.1.0-beta.1

Complete security-driven rewrite. **Every public API from 0.0.1 is
replaced.** See `MIGRATION.md` for the upgrade path.

### Security

- **Merchant credentials removed from the client.** `BankAlfalahConfig`
  (merchant password, hash, AES keys) is gone. Sessions are created by
  your backend through the new `BankAlfalahSessionProvider` contract.
- **Payment success is no longer inferred from URL substrings.**
  Redirects are matched strictly against the session's return URI
  (scheme, host, port, path); unknown URLs never affect payment state.
- **Backend verification is mandatory.** A redirect produces
  `PaymentCompleted` only after `verifyPayment` confirms it server-side.
- **Sensitive logging removed.** The new `PaymentLogger` is off by
  default and redacts credential-like keys.
- **HTML escaping.** Optional POST-form hand-off escapes all field names
  and values; client-side AES hashing (`encrypt`, `crypto`) is removed.

### Reliability

- Exactly-once completion: redirect, cancel, timeout, WebView error, and
  route dismissal race safely; one `PaymentResult` per checkout.
- Single navigation owner: the checkout screen pops itself exactly once.
- Cancellable 5-minute timeout (configurable) backed by a `Timer`.
- Non-main-frame resource errors no longer abort checkout.

### API

- New entry point: `BankAlfalahPayment(environment:, sessionProvider:)`.
- Typed money: `Money.pkr(2500)` (validated, minor-units based).
- Typed results: sealed `PaymentResult` (`PaymentCompleted`,
  `PaymentFailed`, `PaymentCancelled`, `PaymentPending`,
  `PaymentTimedOut`, `PaymentVerificationFailed`, `PaymentError`).
- Typed errors: `BankAlfalahException` hierarchy.
- Lifecycle hooks via `PaymentLifecycleObserver`.
- Dependencies reduced to `webview_flutter` + `meta`
  (`http`, `crypto`, `encrypt`, `uuid` removed).

## 0.0.1

- Initial release (deprecated; insecure client-side integration).
