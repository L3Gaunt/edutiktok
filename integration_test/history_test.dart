import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:edutiktok/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('History Screen Tests', () {
    setUpAll(() async {
      await Firebase.initializeApp();
      // Sign in with test account
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'testpassword123',
      );
    });

    tearDownAll(() async {
      await FirebaseAuth.instance.signOut();
    });

    testWidgets('History screen shows viewed videos', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to History screen
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Verify we're on the History screen
      expect(find.text('My History'), findsOneWidget);

      // Initially, we should see either videos or the empty state message
      expect(
        find.byType(ListView).union(
          find.text('No videos viewed yet. Start watching some videos!'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Liked videos filter works', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to History screen
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Find and toggle the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify the switch is toggled
      final Switch switchWidget = tester.widget(find.byType(Switch));
      expect(switchWidget.value, isTrue);

      // We should see either liked videos or the empty state message
      expect(
        find.byType(ListView).union(
          find.text('No liked videos in your history'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Navigation between screens works', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test navigation to History
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('My History'), findsOneWidget);

      // Test navigation to Feed
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.text('My History'), findsNothing);

      // Test navigation to Upload
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('Upload Video'), findsOneWidget);

      // Back to History
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('My History'), findsOneWidget);
    });
  });
} 