import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const SodamrokApp());
}

class SodamrokApp extends StatelessWidget {
  const SodamrokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '소담록',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AppShell(),
    );
  }
}
