import 'package:flutter/foundation.dart' show kIsWeb;
import 'app/main_parent_mobile.dart' as mobile;
import 'app/main_admin_web.dart' as admin_web;

/// Platform Dispatcher - Main Entry Point
///
/// This project now separates the apps explicitly:
/// - Admin Dashboard: Web-only entrypoint -> `lib/app/main_admin_web.dart`
/// - Parent App: Mobile-only entrypoint -> `lib/app/main_parent_mobile.dart`
///
/// The dispatcher will run the Admin app when running on web (kIsWeb),
/// otherwise it runs the Parent mobile app. Parent web support has been
/// removed; to run the admin or parent apps directly, use the explicit
/// --target flag.
void main() {
  if (kIsWeb) {
    // Web: run Admin Dashboard
    admin_web.main();
  } else {
    // Non-web (mobile): run Parent mobile app
    mobile.main();
  }  
}
