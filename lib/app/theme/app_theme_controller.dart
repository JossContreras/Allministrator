import 'dart:convert';
import 'package:allministrator/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'app_visual_style.dart';

enum AppThemePreference { system, light, dark }

class AppThemeController extends ChangeNotifier {
  AppThemeController(this._database) {
    _load();
  }
  final AppDatabase _database;
  bool _isDisposed = false;
  AppThemePreference preference = AppThemePreference.system;
  AppVisualStyle visualStyle = AppVisualStyle.classic;
  ThemeMode get themeMode => switch (preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
  Future<void> _load() async {
    final values = await Future.wait([
      _readSetting('theme'),
      _readSetting('visualStyle'),
    ]);
    final themeValue = values[0];
    final styleValue = values[1];
    if (themeValue is String) {
      preference = AppThemePreference.values.firstWhere(
        (item) => item.name == themeValue,
        orElse: () => AppThemePreference.system,
      );
    }
    if (styleValue is String) {
      visualStyle = AppVisualStyle.values.firstWhere(
        (item) => item.name == styleValue,
        orElse: () => AppVisualStyle.classic,
      );
    }
    _notify();
  }

  Future<void> setPreference(AppThemePreference value) async {
    preference = value;
    _notify();
    await _writeSetting('theme', value.name);
  }

  Future<void> setVisualStyle(AppVisualStyle value) async {
    visualStyle = value;
    _notify();
    await _writeSetting('visualStyle', value.name);
  }

  Future<Object?> _readSetting(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.valueJson);
  }

  Future<void> _writeSetting(String key, String value) async {
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            id: key,
            key: key,
            valueJson: jsonEncode(value),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
