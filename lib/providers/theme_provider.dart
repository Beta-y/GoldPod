import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = "isDarkMode";
  ThemeMode _themeMode = ThemeMode.system; // 默认改为亮色

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDarkMode = prefs.getBool(_themeKey) ?? false;
    _themeMode = savedDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool(_themeKey, !isDarkMode);
    notifyListeners();
  }

  void initialize(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
