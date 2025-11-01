// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web-specific file download implementation
///
/// Note: `dart:html` is flagged as deprecated by the analyzer in favor of
/// `package:web` + `dart:js_interop`. This code remains a small, focused
/// web-only helper. We suppress the deprecation warning here to avoid
/// widespread changes. If you want to adopt the newer APIs, migrate to
/// `package:web` and `dart:js_interop` later.
void downloadFile(List<int> bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
