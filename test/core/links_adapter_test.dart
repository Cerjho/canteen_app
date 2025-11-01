import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/link_provider.dart';
import 'package:canteen_app/core/links_adapter.dart';

class FakeProvider implements LinkProvider {
  final StreamController<dynamic> controller = StreamController<dynamic>();
  @override
  Stream<dynamic> get uriLinkStream => controller.stream;
  void add(dynamic e) => controller.add(e);
  Future<void> close() => controller.close();
}

void main() {
  test('LinksAdapter normalizes string and Uri events', () async {
    final fake = FakeProvider();
    final adapter = LinksAdapter(fake);

    final results = <Uri?>[];
    final sub = adapter.uriStream.listen(results.add);

    fake.add('myapp://payment-callback?status=ok&session_id=123');
    fake.add(Uri.parse('myapp://payment-callback?status=done&session_id=abc'));

    // Give microtask loop a moment to deliver stream events
    await Future.delayed(const Duration(milliseconds: 10));

    expect(results.length, 2);
    expect(results[0]?.host, 'payment-callback');
    expect(results[0]?.queryParameters['status'], 'ok');
    expect(results[1]?.queryParameters['status'], 'done');

    await sub.cancel();
    await fake.close();
  });
}
