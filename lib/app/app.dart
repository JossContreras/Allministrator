import 'package:allministrator/app/constants/app_constants.dart';
import 'package:allministrator/app/dependencies.dart';
import 'package:allministrator/app/router/app_router.dart';
import 'package:allministrator/app/theme/app_theme.dart';
import 'package:allministrator/app/theme/app_theme_controller.dart';
import 'package:allministrator/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

final appRouter = createAppRouter(documentRepository);
final appThemeController = AppThemeController(appDatabase);

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});
  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  late final AppThemeController _themeController;
  @override
  void initState() {
    super.initState();
    _themeController = appThemeController..addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _themeController.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppConstants.applicationName,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: _themeController.themeMode,
    themeAnimationDuration: AppMotion.normal,
    themeAnimationCurve: AppMotion.state,
    routerConfig: appRouter,
  );
}
