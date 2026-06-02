import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'screens/main_navigation.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase.
  await SupabaseService.initialize();

  // Set preferred orientations to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ATFAApp());

  // Do not block first frame on a network call; start anonymous session in
  // the background so iOS launch watchdog does not kill the app.
  unawaited(SupabaseService.ensureSession());
}

class ATFAApp extends StatefulWidget {
  const ATFAApp({super.key});

  @override
  State<ATFAApp> createState() => _ATFAAppState();

  // Global key to access state from anywhere
  static _ATFAAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ATFAAppState>();
}

class _ATFAAppState extends State<ATFAApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('themeMode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeModeIndex];
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ATFA - Auto Diagnostic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigation(),
    );
  }
}
