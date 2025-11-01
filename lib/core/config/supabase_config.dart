import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// Supabase configuration and initialization
/// 
/// This module handles Supabase client initialization and provides
/// easy access to Supabase services throughout the app.
class SupabaseConfig {
  static SupabaseClient? _client;
  
  /// Initialize Supabase
  /// 
  /// Must be called before using any Supabase features.
  /// Typically called in main() during app initialization.
  static Future<void> initialize() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
          'Supabase credentials not found in .env file. '
          'Please add SUPABASE_URL and SUPABASE_ANON_KEY to your .env file.'
        );
      }
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce, // More secure auth flow
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );
      
      _client = Supabase.instance.client;
      AppLogger.info('Supabase initialized successfully');
      AppLogger.info('Supabase URL: $supabaseUrl');
      
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize Supabase',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Get the Supabase client instance
  /// 
  /// Throws an exception if Supabase hasn't been initialized yet.
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseConfig.initialize() first.'
      );
    }
    return _client!;
  }
  
  /// Check if Supabase is initialized
  static bool get isInitialized => _client != null;
  
  /// Get current authenticated user
  static User? get currentUser => client.auth.currentUser;
  
  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
  
  /// Get user role from metadata
  static bool get isAdmin {
    final metadata = currentUser?.userMetadata;
    return metadata?['isAdmin'] == true;
  }
  
  /// Get user role from metadata
  static bool get isParent {
    final metadata = currentUser?.userMetadata;
    return metadata?['isParent'] == true;
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
      AppLogger.info('User signed out successfully');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to sign out',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
  
  /// Call an Edge Function
  /// 
  /// Example:
  /// ```dart
  /// final response = await SupabaseConfig.callFunction(
  ///   'set_user_role',
  ///   body: {'user_id': userId, 'isAdmin': true},
  /// );
  /// ```
  static Future<FunctionResponse> callFunction(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      AppLogger.info('Calling function: $functionName');
      
      final response = await client.functions.invoke(
        functionName,
        body: body,
        headers: headers,
      );
      
      AppLogger.info('Function $functionName completed: ${response.status}');
      return response;
      
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to call function: $functionName',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
