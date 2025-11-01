import 'dart:async';

/// Abstract provider interface for deep-link event sources.
///
/// Implement this to wrap platform libraries (AppLinks, uni_links, etc.) and make
/// `LinksAdapter` easily testable by injecting fake providers.
abstract class LinkProvider {
  /// A stream that emits either `String` or `Uri` deep-link events depending on
  /// the underlying library implementation.
  Stream<dynamic> get uriLinkStream;
}
