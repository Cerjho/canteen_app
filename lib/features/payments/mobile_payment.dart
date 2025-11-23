import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:canteen_app/core/links_adapter.dart';

/// Mobile payment helper using hosted checkout flow.
///
/// Usage:
/// - Call createPaymentSession(amount, orderId) to get a checkout_url from the Worker.
/// - Open the checkout_url using url_launcher (external browser recommended).
/// - Listen to deep links (myapp://payment-callback) via uni_links to detect completion.
///
class MobilePaymentWidget extends StatefulWidget {
  final String workerBaseUrl; // e.g. https://payments.example.workers.dev
  final String orderId;
  final int amount; // in smallest currency unit (centavos)
  final LinksAdapter? linksAdapter;

  const MobilePaymentWidget({
    super.key,
    required this.workerBaseUrl,
    required this.orderId,
    required this.amount,
    this.linksAdapter,
  });

  @override
  State<MobilePaymentWidget> createState() => _MobilePaymentWidgetState();
}

class _MobilePaymentWidgetState extends State<MobilePaymentWidget> {
  StreamSubscription? _sub;
  String _status = 'idle';

  @override
  void initState() {
    super.initState();
    // Listen for deep links via the provided LinksAdapter (or default adapter)
    final adapter = widget.linksAdapter ?? LinksAdapter.defaultAdapter;
    _sub = adapter.uriStream.listen((Uri? uri) {
      if (uri == null) return;
      if (uri.scheme == 'myapp' && uri.host == 'payment-callback') {
        final status = uri.queryParameters['status'] ?? 'unknown';
        final session = uri.queryParameters['session_id'] ?? uri.queryParameters['payment_id'];
        setState(() {
          _status = 'result: $status (session: $session)';
        });
        // Optionally confirm with backend or refresh Supabase
      }
    }, onError: (err) {
      // handle errors
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() => _status = 'creating session');
    final url = Uri.parse('${widget.workerBaseUrl.replaceAll(RegExp(r'/+\$'), '')}/create-payment-session');
    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': widget.amount,
          'currency': 'PHP',
          'orderId': widget.orderId,
          'return_url': 'myapp://payment-callback',
          'metadata': {'orderId': widget.orderId}
        }));
    if (resp.statusCode != 200) {
      setState(() => _status = 'create session failed: ${resp.statusCode}');
      return;
    }
    final body = jsonDecode(resp.body);
    final checkoutUrl = body['checkout_url'] as String?;
    if (checkoutUrl == null) {
      setState(() => _status = 'no checkout url');
      return;
    }

    setState(() => _status = 'opening checkout');
    final uri = Uri.parse(checkoutUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      setState(() => _status = 'could not open checkout');
    } else {
      setState(() => _status = 'checkout opened');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _startPayment,
          child: const Text('Pay now'),
        ),
        const SizedBox(height: 12),
        Text('Status: $_status'),
      ],
    );
  }
}
