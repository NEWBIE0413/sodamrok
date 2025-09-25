import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sodamrok/app/app_shell.dart';
import 'package:sodamrok/core/dependencies/app_dependencies.dart';
import 'package:sodamrok/features/auth/application/auth_controller.dart';

void main() {
  testWidgets('Profile prompts login modal when unauthenticated', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppDependencies.configure();

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    expect(AppDependencies.authController.status, AuthStatus.unauthenticated);

    await tester.tap(find.text('프로필').last);
    await tester.pumpAndSettle();

    final loginButton = find.text('로그인하기');
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('소담록 로그인'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('로그인하기'), findsOneWidget);
  });
}
