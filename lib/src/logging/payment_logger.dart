import 'package:flutter/foundation.dart';

/// Redacting logger for the payment SDK.
///
/// Disabled by default. When enabled it logs only explicit metadata and
/// redacts any key that looks credential-like, so gateway payloads,
/// tokens, hashes, and card data can never leak into logs.
abstract final class PaymentLogger {
  /// Enables or disables SDK debug logging. Off by default.
  static bool enabled = false;

  /// Optional sink override; defaults to [debugPrint]. Useful in tests
  /// or to route logs into an app's own logging pipeline.
  static void Function(String message)? sink;

  static const _sensitiveKeyFragments = [
    'password',
    'secret',
    'token',
    'hash',
    'key',
    'cookie',
    'authorization',
    'auth',
    'card',
    'pan',
    'cvv',
    'pin',
  ];

  /// Logs [message] with optional [metadata]. Values whose keys look
  /// sensitive are replaced with `<redacted>`.
  static void debug(String message,
      {Map<String, Object?> metadata = const {}}) {
    if (!enabled) return;
    final redacted = redact(metadata);
    final suffix = redacted.isEmpty ? '' : ' $redacted';
    (sink ?? debugPrint)('[bank_alfalah_payment] $message$suffix');
  }

  /// Returns a copy of [metadata] with sensitive-looking values redacted.
  @visibleForTesting
  static Map<String, Object?> redact(Map<String, Object?> metadata) {
    return metadata.map((key, value) {
      final lower = key.toLowerCase();
      final sensitive =
          _sensitiveKeyFragments.any((fragment) => lower.contains(fragment));
      return MapEntry(key, sensitive ? '<redacted>' : value);
    });
  }
}
