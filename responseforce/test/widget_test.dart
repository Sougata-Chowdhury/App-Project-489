// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:responseforce/screens/role_select_screen.dart';
import 'package:responseforce/state/app_state.dart';

void main() {
  testWidgets('Role select shows Elder/Admin buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: RoleSelectScreen()),
      ),
    );

    expect(find.text('Continue as Elder'), findsOneWidget);
    expect(find.text('Continue as Admin'), findsOneWidget);
  });
}
