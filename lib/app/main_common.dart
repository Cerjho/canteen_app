import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/firebase_options.dart';
import '../core/utils/app_logger.dart';

/// Common initialization logic shared across all app entry points
/// 
/// This module contains all the Firebase and environment setup code
/// that both admin and parent apps need to initialize.
/// 
/// **Usage:**
/// ```dart
/// await initializeApp();
/// runApp(MyApp());
/// ```
class AppInitializer {
  /// Initialize common services and configurations
  /// 
  /// This includes:
  /// - Environment variables (.env)
  /// - Firebase Core
  /// - Firestore with offline persistence
  /// - Firebase Crashlytics
  /// - Firebase Analytics
  /// - Logger
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize logger
    AppLogger.init();
    
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      AppLogger.info('Environment variables loaded successfully');
      
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info('Firebase initialized successfully');
      
      // Enable Firestore offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      AppLogger.info('Firestore persistence enabled');
      
      // Initialize Firebase Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        AppLogger.error(
          'Flutter error',
          error: errorDetails.exception,
          stackTrace: errorDetails.stack,
        );
      };
      
      // Initialize Firebase Analytics
      FirebaseAnalytics analytics = FirebaseAnalytics.instance;
      await analytics.logAppOpen();
      AppLogger.info('Firebase Analytics initialized');
      
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize app', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Build error screen widget when initialization fails
  static Widget buildErrorScreen(Object error) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
