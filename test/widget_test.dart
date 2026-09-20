// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mmc_app/main.dart';

void main() {
  testWidgets('MMC login accepts username without a password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MmcApp());

    expect(find.text('Welcome to MMC'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Enter MMC'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ava');
    await tester.tap(find.text('Enter MMC'));
    await tester.pumpAndSettle();

    expect(find.text('MMC talk'), findsOneWidget);
    expect(find.text('A QUIETER KIND OF CONNECTION'), findsNothing);
  });
}
