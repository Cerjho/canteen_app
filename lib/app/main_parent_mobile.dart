import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/config/app_theme.dart';
import '../router/router.dart';
import '../core/config/theme_mode_provider.dart';
import 'main_common.dart';

/// Entry point for Mobile (Parent App)
/// 
/// **Platform:** Android & iOS
/// **Target Users:** Parents/Guardians
/// 
/// **Features:**
/// - Parent dashboard
/// - View linked students
/// - Browse menu and place orders
/// - Request balance top-ups
/// - View order history
/// - Manage profile
/// - Shared login with automatic role-based routing
/// 
/// **To run:**
/// ```bash
/// flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart  # Android
/// flutter run -d iPhone --target lib/app/main_parent_mobile.dart         # iOS
/// ```
void main() async {
  try {
    // Initialize common services
    await AppInitializer.initialize();
    
    runApp(
      const ProviderScope(
        child: ParentApp(),
      ),
    );
  } catch (e) {
    // Show error screen if initialization fails
    runApp(AppInitializer.buildErrorScreen(e));
  }
}

/// Parent Mobile App Widget
/// 
/// Material 3 themed app for parents/guardians with:
/// - Mobile-optimized UI
/// - Bottom navigation or drawer
/// - Student management
/// - Order placement
/// - Balance top-up requests
/// - Order history
class ParentApp extends ConsumerWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Note: Deep-link to /complete-registration is handled in router redirect

    return ScreenUtilInit(
      designSize: const Size(360, 690), // Mobile-first base design
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Loheca Canteen',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
