/// Platform-agnostic file download interface.
/// 
/// Automatically imports the correct implementation based on platform:
/// - Web: Uses dart:html for browser downloads
/// - Mobile: Throws UnsupportedError (use share or storage instead)
library;

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
