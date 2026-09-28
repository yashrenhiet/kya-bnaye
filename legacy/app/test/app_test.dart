import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyabnaye/bootstrap/app.dart';

void main() {
  group('KyaBnayeApp', () {
    testWidgets('boots to the Home tab and shows all four nav destinations', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: KyaBnayeApp()));
      await tester.pumpAndSettle();

      expect(find.text('Kya Bnaye?'), findsOneWidget);
      expect(
        find.widgetWithText(NavigationDestination, 'Home'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Pantry'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Recipes'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Shopping'),
        findsOneWidget,
      );
    });

    testWidgets("tapping a tab navigates to that tab's placeholder screen", (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: KyaBnayeApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'Pantry'));
      await tester.pumpAndSettle();

      expect(find.text('Pantry'), findsWidgets);
      expect(find.text('Pantry — coming soon'), findsOneWidget);
    });
  });
}
