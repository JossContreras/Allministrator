import 'dart:convert';
import 'package:allministrator/core/database/app_database.dart';
import 'package:flutter/material.dart';

enum AppThemePreference { system, light, dark }

class AppThemeController extends ChangeNotifier {
  AppThemeController(this._database) {
    _load();
  }
  final AppDatabase _database;
  AppThemePreference preference = AppThemePreference.system;
  ThemeMode get themeMode => switch (preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
  Future<void> _load() async {
    final row = await (_database.select(
      _database.settings,
    )..where((s) => s.key.equals('theme'))).getSingleOrNull();
    if (row == null) return;
    final value = jsonDecode(row.valueJson);
    if (value is String) {
      preference = AppThemePreference.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AppThemePreference.system,
      );
      notifyListeners();
    }
  }

  Future<void> setPreference(AppThemePreference value) async {
    preference = value;
    notifyListeners();
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            id: 'theme',
            key: 'theme',
            valueJson: jsonEncode(value.name),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
