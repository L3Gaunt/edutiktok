import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:edutiktok/main.dart';

class TestApp extends StatelessWidget {
  final FirebaseAuth auth;

  const TestApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const HomePage();
          }
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
            ],
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  const testEmail = 'test@example.com';
  const testPassword = 'password123';
  const wrongPassword = 'wrongpassword';
  const nonExistentEmail = 'nonexistent@example.com';

  setUp(() async {
    await Firebase.initializeApp();
    
    auth = FirebaseAuth.instance;
    await auth.useAuthEmulator('localhost', 9099);

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    await auth.signOut();

    try {
      await auth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
    } catch (e) {
      // User might already exist, that's fine
    }
    await auth.signOut();
  });

  group('Authentication Tests', () {
    testWidgets('Successful sign in and sign out flow', (WidgetTester tester) async {
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      // Initially should show sign in screen
      expect(find.byType(SignInScreen), findsOneWidget);

      // Sign in
      await auth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      await tester.pumpAndSettle();

      // Should show home page with navigation bar
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Sign out
      await auth.signOut();
      await tester.pumpAndSettle();

      // Should return to sign in screen
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('Sign in with wrong password fails', (WidgetTester tester) async {
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);

      try {
        await auth.signInWithEmailAndPassword(
          email: testEmail,
          password: wrongPassword,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<FirebaseAuthException>());
        expect((e as FirebaseAuthException).code, 'wrong-password');
      }

      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Sign in with non-existent email fails', (WidgetTester tester) async {
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);

      try {
        await auth.signInWithEmailAndPassword(
          email: nonExistentEmail,
          password: testPassword,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<FirebaseAuthException>());
        expect((e as FirebaseAuthException).code, 'user-not-found');
      }

      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Create new account flow', (WidgetTester tester) async {
      final newEmail = 'newuser${DateTime.now().millisecondsSinceEpoch}@example.com';
      final newPassword = 'newpassword123';

      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);

      // Create new account
      await auth.createUserWithEmailAndPassword(
        email: newEmail,
        password: newPassword,
      );
      await tester.pumpAndSettle();

      // Should show home page with navigation bar
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);

      // Sign out
      await auth.signOut();
      await tester.pumpAndSettle();

      // Sign in with new account
      await auth.signInWithEmailAndPassword(
        email: newEmail,
        password: newPassword,
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
    });

    testWidgets('Create account with existing email fails', (WidgetTester tester) async {
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);

      try {
        await auth.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<FirebaseAuthException>());
        expect((e as FirebaseAuthException).code, 'email-already-in-use');
      }

      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Password reset flow', (WidgetTester tester) async {
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);

      // Request password reset
      await auth.sendPasswordResetEmail(email: testEmail);

      // Verify we're still on sign in screen
      expect(find.byType(SignInScreen), findsOneWidget);

      // Try password reset for non-existent email
      try {
        await auth.sendPasswordResetEmail(email: nonExistentEmail);
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<FirebaseAuthException>());
        expect((e as FirebaseAuthException).code, 'user-not-found');
      }
    });

    testWidgets('Auth persistence test', (WidgetTester tester) async {
      // First sign in
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      await auth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      await tester.pumpAndSettle();

      // Should show home page with navigation bar
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);

      // Rebuild app to simulate app restart
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      // Should still be signed in and show home page
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
    });
  });
} 