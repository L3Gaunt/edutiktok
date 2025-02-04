import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FirebaseUI Auth with all providers
  FirebaseUIAuth.configureProviders([
    EmailAuthProvider(),
    EmailLinkAuthProvider(
      actionCodeSettings: ActionCodeSettings(
        url: 'https://edutiktok-firebase-app.firebaseapp.com',
        handleCodeInApp: true,
        androidPackageName: 'com.luckylab.edutiktok',
        androidMinimumVersion: '1',
      ),
    ),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTikTok',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: FirebaseAuth.instance.currentUser == null ? '/sign-in' : '/home',
      routes: {
        '/sign-in': (context) => SignInScreen(
          providers: [
            EmailAuthProvider(),
            EmailLinkAuthProvider(
              actionCodeSettings: ActionCodeSettings(
                url: 'https://edutiktok-firebase-app.firebaseapp.com',
                handleCodeInApp: true,
                androidPackageName: 'com.luckylab.edutiktok',
                androidMinimumVersion: '1',
              ),
            ),
          ],
          actions: [
            AuthStateChangeAction<SignedIn>((context, state) {
              Navigator.pushReplacementNamed(context, '/home');
            }),
          ],
        ),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduTikTok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => ProfileScreen(
                    providers: [
                      EmailAuthProvider(),
                      EmailLinkAuthProvider(
                        actionCodeSettings: ActionCodeSettings(
                          url: 'https://edutiktok-firebase-app.firebaseapp.com',
                          handleCodeInApp: true,
                          androidPackageName: 'com.luckylab.edutiktok',
                          androidMinimumVersion: '1',
                        ),
                      ),
                    ],
                    actions: [
                      SignedOutAction((context) {
                        Navigator.pushReplacementNamed(context, '/sign-in');
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to EduTikTok!'),
      ),
    );
  }
}
