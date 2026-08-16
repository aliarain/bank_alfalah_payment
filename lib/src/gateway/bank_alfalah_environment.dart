/// The Bank Alfalah environment a checkout targets.
///
/// The environment is informational for the client: the merchant backend
/// decides which gateway endpoints to use when it creates the session.
/// Gateway URLs are never hardcoded in the Flutter SDK.
enum BankAlfalahEnvironment {
  /// Bank Alfalah sandbox / test gateway.
  sandbox,

  /// Bank Alfalah production gateway.
  production,
}
