import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../gateway/redirect_parser.dart';
import '../logging/payment_logger.dart';
import '../models/checkout_session.dart';
import 'checkout_controller.dart';

/// Presents the bank-hosted checkout in a WebView.
///
/// The screen owns route dismissal: it pops itself exactly once when its
/// [CheckoutController] completes, regardless of which event completed
/// it. It knows nothing about gateway response codes — redirect
/// classification lives in [RedirectParser].
class CheckoutScreen extends StatefulWidget {
  /// Creates a checkout screen for [session] driven by [controller].
  const CheckoutScreen({
    super.key,
    required this.session,
    required this.controller,
    required this.redirectParser,
    this.title = 'Payment',
  });

  /// The backend-created session to present.
  final CheckoutSession session;

  /// Lifecycle owner for this checkout attempt.
  final CheckoutController controller;

  /// Strict matcher for the gateway's return redirect.
  final RedirectParser redirectParser;

  /// App bar title.
  final String title;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    widget.controller.start();
    widget.controller.outcome.whenComplete(_popOnce);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: _onWebResourceError,
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    _load();
  }

  void _load() {
    final fields = widget.session.formFields;
    if (fields == null) {
      _webViewController.loadRequest(widget.session.checkoutUri);
    } else {
      _webViewController.loadHtmlString(_buildFormHtml(fields));
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final decision = widget.redirectParser.parse(request.url);
    switch (decision) {
      case RedirectMatched():
        PaymentLogger.debug('Return redirect received', metadata: {
          'transactionId': widget.session.transactionId,
          'outcome': decision.outcome.name,
        });
        widget.controller.complete(CheckoutRedirected(decision));
        return NavigationDecision.prevent;
      case RedirectIgnored():
        return NavigationDecision.navigate;
    }
  }

  void _onWebResourceError(WebResourceError error) {
    // Sub-resource failures (images, analytics scripts) must not abort
    // a checkout; only a main-frame failure is fatal.
    if (!(error.isForMainFrame ?? true)) return;
    widget.controller.complete(
      CheckoutErrored(
        'Checkout page failed to load '
        '(${error.errorCode}: ${error.errorType?.name ?? 'unknown'})',
        error: error.description,
      ),
    );
  }

  /// Escapes every field name and value so session data can never break
  /// out of the generated form or inject markup.
  String _buildFormHtml(Map<String, String> fields) {
    const escape = HtmlEscape(HtmlEscapeMode.attribute);
    final action = escape.convert(widget.session.checkoutUri.toString());
    final inputs = fields.entries
        .map((e) => '<input type="hidden" '
            'name="${escape.convert(e.key)}" '
            'value="${escape.convert(e.value)}">')
        .join('\n');
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Redirecting to checkout</title>
</head>
<body>
  <form id="checkout" action="$action" method="post">$inputs</form>
  <script>document.getElementById('checkout').submit();</script>
</body>
</html>
''';
  }

  void _popOnce() {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  Future<void> _requestClose() async {
    if (widget.controller.isCompleted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'The payment has not finished. Are you sure you want to close?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continue payment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      widget.controller.complete(const CheckoutCancelled());
    }
  }

  @override
  void dispose() {
    // If the route is dismissed by any other means (predictive back,
    // popUntil, deep link), resolve the checkout as cancelled.
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close checkout',
            onPressed: _requestClose,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading checkout',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
