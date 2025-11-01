import 'dart:async';

import 'package:app_links/app_links.dart';

import 'link_provider.dart';

/// LinksAdapter centralizes deep-link handling and is testable by injecting
/// a `LinkProvider` implementation.
class LinksAdapter {
  /// Construct with a provider. In production prefer using
  /// `LinksAdapter.defaultAdapter` which uses `AppLinks`.
  LinksAdapter(LinkProvider provider) : _provider = provider;

  final LinkProvider _provider;

  /// Production singleton using the real AppLinks provider.
  static final LinksAdapter defaultAdapter = LinksAdapter(_AppLinksProvider());

  /// Backwards-compatible alias used by existing call sites that expect a
  /// global instance. Prefer using dependency injection when writing tests.
  static LinksAdapter instance = defaultAdapter;

  /// Stream that emits normalized Uri objects (or null on parse failure).
  Stream<Uri?> get uriStream => _provider.uriLinkStream.map((dynamic event) {
        if (event == null) return null;
        if (event is Uri) return event;
        return Uri.tryParse(event.toString());
      });
}

/// Small adapter that implements [LinkProvider] with the `app_links` package.
class _AppLinksProvider implements LinkProvider {
  final AppLinks _appLinks = AppLinks();
  @override
  Stream<dynamic> get uriLinkStream => _appLinks.uriLinkStream;
}
