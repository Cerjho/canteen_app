import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ThemeMode provider for toggling between light and dark mode
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
