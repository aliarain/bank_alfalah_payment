# Migrating from 0.0.1 to 0.1.0

`0.1.0` is a complete, deliberate breaking rewrite. `0.0.1` required
Bank Alfalah merchant credentials (password, hash, AES keys) inside the
Flutter app and decided payment success from a URL substring. Both are
security defects: app binaries can be decompiled, and any web page
containing `RC-00` could mark a payment successful. **The insecure API
was not preserved; security improvements justify breaking
compatibility.**

## What changed

| 0.0.1 | 0.1.0 |
| --- | --- |
| `BankAlfalahConfig` with credentials in the app | Gone — credentials live on **your backend** |
| SDK builds the gateway request + hash client-side | Backend creates a session via `BankAlfalahSessionProvider.createSession` |
| Success = URL contains `RC-00` | Strict return-URI matching + mandatory backend `verifyPayment` |
| `PaymentRequest(amount: "100")` (string, unused!) | `CheckoutRequest(amount: Money.pkr(100), orderId: ...)` — typed and actually used |
| `PaymentResult.status` enum + nullable fields | Sealed `PaymentResult` (`PaymentCompleted`, `PaymentFailed`, `PaymentCancelled`, `PaymentPending`, `PaymentTimedOut`, `PaymentVerificationFailed`, `PaymentError`) |
| Callbacks could fire and pop routes twice | Exactly-once completion; the checkout screen owns navigation |
| Full payload `print()` logging | Off-by-default `PaymentLogger` with credential redaction |
| Deps: `http`, `crypto`, `encrypt`, `uuid`, `webview_flutter` | Deps: `webview_flutter`, `meta` |

## Migration steps

1. **Move credentials to your server.** Build two endpoints:
   - `POST /payments/create` — creates the Bank Alfalah transaction
     (all hashing/credentials here) and returns
     `{transactionId, checkoutUrl, returnUrl, formFields?}`.
   - `GET /payments/{id}/verify` — verifies the transaction
     server-to-server and returns `{status, transactionId, ...}`.
2. **Delete `BankAlfalahConfig`** and every credential string from your
   app and its git history; rotate any credentials that shipped in a
   released binary.
3. **Implement the provider:**

   ```dart
   class MyBackendSessionProvider implements BankAlfalahSessionProvider {
     @override
     Future<CheckoutSession> createSession(CheckoutRequest request) async =>
         CheckoutSession.fromJson(await api.post('/payments/create', request.toJson()));

     @override
     Future<PaymentVerification> verifyPayment(String transactionId) async =>
         PaymentVerification.fromJson(await api.get('/payments/$transactionId/verify'));
   }
   ```

4. **Replace the call site:**

   ```dart
   // Before (0.0.1)
   final service = BankAlfalahPaymentService(config: config);
   final result = await service.initiatePayment(request: request, context: context);
   if (result.isSuccess) { ... }

   // After (0.1.0)
   final bankAlfalah = BankAlfalahPayment(
     environment: BankAlfalahEnvironment.sandbox,
     sessionProvider: MyBackendSessionProvider(),
   );
   final result = await bankAlfalah.startCheckout(
     context: context,
     request: CheckoutRequest(amount: Money.pkr(100), orderId: 'ORDER-1'),
   );
   if (result is PaymentCompleted) { ... }
   ```

5. **Fulfill orders only on `PaymentCompleted`** (backend-verified), and
   handle `PaymentPending` by confirming server-side.
