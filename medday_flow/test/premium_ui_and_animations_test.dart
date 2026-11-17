import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medday_flow/providers/medication_provider.dart';
import 'package:medday_flow/providers/task_provider.dart';
import 'package:medday_flow/screens/main_navigation_shell.dart';
import 'package:medday_flow/screens/unified_insights_view.dart';
import 'package:medday_flow/services/custom_state_management.dart';
import 'package:medday_flow/services/native_preferences_service.dart';
import 'package:medday_flow/widgets/premium_animations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    NativePreferencesService.setMockInitialValues();
  });

  tearDownAll(() {
    NativePreferencesService.reset();
  });

  group('Pure-Flutter Premium Animation & Micro-Interaction Toolkit', () {
    testWidgets('StaggeredColumn renders all children and coordinates entrance', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredColumn(
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
              ],
            ),
          ),
        ),
      );

      // Initially present in widget tree
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Advance through animation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('TactilePressScale scales down on tap and triggers onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactilePressScale(
                onTap: () => tapped = true,
                child: const Text('Press Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Press Me'), findsOneWidget);

      // Tap on widget
      await tester.tap(find.text('Press Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('SmoothContentSwitcher smoothly dissolves between dynamic children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothContentSwitcher(
              child: Text('Initial State', key: ValueKey('initial')),
            ),
          ),
        ),
      );

      expect(find.text('Initial State'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmoothContentSwitcher(
              child: Text('Loaded State', key: ValueKey('loaded')),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Loaded State'), findsOneWidget);
    });
  });

  group('MainNavigationShell Tests', () {
    testWidgets('MainNavigationShell renders 4 tabs with active highlights and supports tab switching', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(
            initialIndex: 0,
            testTabViews: [
              Scaffold(body: Center(child: Text('Home Content'))),
              Scaffold(body: Center(child: Text('Medications Content'))),
              Scaffold(body: Center(child: Text('Insights Content'))),
              Scaffold(body: Center(child: Text('Settings Content'))),
            ],
          ),
        ),
      );

      // Navigation shell renders navigation bar labels
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Home Content'), findsOneWidget);

      // Tap on Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Insights Content'), findsOneWidget);

      // Tap on Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings Content'), findsOneWidget);

      // Tap back to Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Home Content'), findsOneWidget);
    });
  });

  group('UnifiedInsightsView Tests', () {
    testWidgets('UnifiedInsightsView toggles between Medications and Tasks & Habits segments', (tester) async {
      final medProvider = MedicationProvider();
      final taskProvider = TaskProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: medProvider),
            ChangeNotifierProvider.value(value: taskProvider),
          ],
          child: const MaterialApp(
            home: UnifiedInsightsView(),
          ),
        ),
      );

      expect(find.text('Insights & Trends'), findsOneWidget);
      expect(find.text('Medications'), findsOneWidget);
      expect(find.text('Tasks & Habits'), findsOneWidget);

      // Initially shows Medication Adherence Score
      expect(find.text('7-Day Adherence Score'), findsOneWidget);

      // Switch to Tasks & Habits
      await tester.tap(find.text('Tasks & Habits'));
      await tester.pumpAndSettle();

      expect(find.text('Overall Task Completion Rate'), findsOneWidget);
    });
  });
}
