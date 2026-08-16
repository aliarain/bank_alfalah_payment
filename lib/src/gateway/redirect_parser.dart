import 'package:meta/meta.dart';

/// What the checkout WebView should do with a navigation request.
@immutable
sealed class RedirectDecision {
  const RedirectDecision();
}

/// The URL is not the gateway's return redirect; let the WebView
/// navigate normally. Unknown URLs never affect payment state.
final class RedirectIgnored extends RedirectDecision {
  const RedirectIgnored();
}

/// The URL strictly matches the session's return URI: checkout has
/// finished and the transaction must now be verified by the backend.
final class RedirectMatched extends RedirectDecision {
  const RedirectMatched({
    required this.outcome,
    required this.parameters,
    this.responseCode,
  });

  /// What the gateway's response code suggests. Advisory only — even
  /// [RedirectOutcome.success] requires backend verification.
  final RedirectOutcome outcome;

  /// The gateway response code carried by the redirect, if present.
  final String? responseCode;

  /// The redirect's query parameters, for diagnostics and backend hints.
  final Map<String, String> parameters;
}

/// The gateway's advisory outcome carried by a matched redirect.
enum RedirectOutcome {
  /// Response code indicates the gateway accepted the payment.
  /// Must still be verified server-side.
  success,

  /// Response code indicates the gateway declined the payment.
  failure,

  /// No recognizable response code; only backend verification can
  /// determine the state.
  unknown,
}

/// Strictly matches gateway return redirects against the session's
/// return URI.
///
/// A URL is treated as the checkout redirect only when its scheme, host,
/// port, and path all equal the expected return URI. Substring checks
/// such as `url.contains('RC-00')` are never used, so a malicious page
/// like `https://evil.example/RC-00` cannot influence payment state.
@immutable
class RedirectParser {
  /// Creates a parser for redirects to [expectedReturnUri].
  ///
  /// [responseCodeParameter] names the query parameter carrying the
  /// gateway response code (Bank Alfalah's HS flow uses `RC`).
  /// [successCodes] and [failureCodes] are matched with string equality.
  const RedirectParser({
    required this.expectedReturnUri,
    this.responseCodeParameter = 'RC',
    this.successCodes = const {'00', 'RC-00'},
    this.failureCodes = const {'01', 'RC-01'},
  });

  /// The return URI the merchant backend registered for this session.
  final Uri expectedReturnUri;

  /// Query parameter holding the gateway response code.
  final String responseCodeParameter;

  /// Codes treated as gateway-side success (still verified server-side).
  final Set<String> successCodes;

  /// Codes treated as gateway-side failure.
  final Set<String> failureCodes;

  /// Classifies [url]. Malformed URLs and URLs that do not exactly
  /// match the return location are ignored.
  RedirectDecision parse(String url) {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      return const RedirectIgnored();
    }

    if (!uri.isAbsolute ||
        uri.scheme != expectedReturnUri.scheme ||
        uri.host.toLowerCase() != expectedReturnUri.host.toLowerCase() ||
        uri.port != expectedReturnUri.port ||
        _normalizePath(uri.path) != _normalizePath(expectedReturnUri.path)) {
      return const RedirectIgnored();
    }

    final params = uri.queryParameters;
    final code = params[responseCodeParameter];
    final outcome = switch (code) {
      final c? when successCodes.contains(c) => RedirectOutcome.success,
      final c? when failureCodes.contains(c) => RedirectOutcome.failure,
      _ => RedirectOutcome.unknown,
    };
    return RedirectMatched(
      outcome: outcome,
      parameters: params,
      responseCode: code,
    );
  }

  static String _normalizePath(String path) => path.isEmpty
      ? '/'
      : (path.length > 1 && path.endsWith('/'))
          ? path.substring(0, path.length - 1)
          : path;
}
