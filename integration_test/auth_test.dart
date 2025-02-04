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

  setUp(() async {
    await Firebase.initializeApp();
    
    // Get the auth instance
    auth = FirebaseAuth.instance;
    
    // Connect to the Firebase Auth Emulator
    await auth.useAuthEmulator('localhost', 9099);

    // Configure Firebase UI Auth providers
    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    // Sign out before each test
    await auth.signOut();

    try {
      // Try to create a test user
      await auth.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
    } catch (e) {
      // User might already exist, that's fine
    }
    // Make sure we're signed out after creating the user
    await auth.signOut();
  });

  group('Authentication Tests', () {
    testWidgets('Basic auth flow test', (WidgetTester tester) async {
      // Build the app with auth instance
      await tester.pumpWidget(TestApp(auth: auth));
      await tester.pumpAndSettle();

      // Verify we start at the sign-in screen
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Welcome to EduTikTok!'), findsNothing);

      // Sign in with the test account
      await auth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );

      // Pump the widget tree to reflect the auth state change
      await tester.pumpAndSettle();

      // Verify we're on the home screen
      expect(find.text('Welcome to EduTikTok!'), findsOneWidget);

      // Sign out
      await auth.signOut();
      await tester.pumpAndSettle();

      // Verify we're back at the sign-in screen
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });
} 