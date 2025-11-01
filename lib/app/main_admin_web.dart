import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import '../core/config/app_theme.dart';
import '../core/config/theme_mode_provider.dart';
import '../router/router.dart';
import 'main_common.dart';

/// Entry point for Web (Admin Dashboard)
/// 
/// **Platform:** Web only
/// **Target Users:** School administrators
/// 
/// **Features:**
/// - Clean URLs (usePathUrlStrategy - no # in URLs)
/// - Full admin dashboard
/// - Student/Parent/Menu/Order/Top-up management
/// - Reports and analytics
/// - Settings and configuration
/// - Shared login with automatic role-based routing
/// 
/// **To run:**
/// ```bash
/// flutter run -d chrome --target lib/app/main_admin_web.dart
/// ```
void main() async {
  // Use path URL strategy for clean URLs on web (removes # from URLs)
  usePathUrlStrategy();
  
  try {
    // Initialize common services
    await AppInitializer.initialize();
    
    runApp(
      const ProviderScope(
        child: AdminApp(),
      ),
    );
  } catch (e) {
    // Show error screen if initialization fails
    runApp(AppInitializer.buildErrorScreen(e));
  }
}

/// Admin Web App Widget
/// 
/// Material 3 themed app for school administrators with:
/// - Full dashboard and management features
/// - Navigation rail for desktop/tablet
/// - Real-time data updates with Firestore
/// - Role-based access control
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Canteen Admin Dashboard',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
