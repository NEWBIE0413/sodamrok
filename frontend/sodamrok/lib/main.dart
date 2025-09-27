import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'app/app_shell.dart';
import 'core/dependencies/app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'package:sodamrok/features/auth/application/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드
  await dotenv.load(fileName: ".env");

  // 카카오맵 SDK 초기화
  await KakaoMapSdk.instance.initialize(dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '');

  await AppDependencies.configure();
  runApp(const SodamrokApp());
}

class SodamrokApp extends StatelessWidget {
  const SodamrokApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = AppDependencies.authController;

    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final status = authController.status;

        Widget home;
        switch (status) {
          case AuthStatus.initializing:
          case AuthStatus.authenticating:
            home = const _SplashScreen();
            break;
          default:
            home = const AppShell();
            break;
        }

        return MaterialApp(
          title: '소담록',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: home,
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
