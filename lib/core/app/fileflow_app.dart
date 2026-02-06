import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/home/view/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:fileflow/features/settings/provider/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileFlowApp extends ConsumerWidget {
  const FileFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);

    return MaterialApp(
      title: 'FileFlow',
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
