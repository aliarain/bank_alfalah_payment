# bank_alfalah_payment example

Runs the full checkout UI against a **mock backend**
(`MockSessionProvider`) so you can try the SDK without Bank Alfalah
credentials or network access.

```bash
cd example
flutter create . --platforms=android,ios   # generate platform folders once
flutter run
```

Pick a scenario (success, gateway decline, verification rejection,
pending, session error) and tap **Pay** to see each `PaymentResult`.

To integrate for real, replace `MockSessionProvider` with a
`BankAlfalahSessionProvider` that calls **your** backend. Never place
Bank Alfalah merchant credentials inside a Flutter app.
