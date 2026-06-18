import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static bool _isDarkMode = false;
  static final List<VoidCallback> _listeners = [];

  static bool get isDarkMode => _isDarkMode;

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('profile_dark_mode') ?? false;
    } catch (_) {}
  }

  static Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_dark_mode', value);
    } catch (_) {}
    for (final listener in _listeners) {
      listener();
    }
  }
}
