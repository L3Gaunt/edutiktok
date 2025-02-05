import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'firebase_options.dart';
import 'screens/video_upload_screen.dart';
import 'screens/video_feed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // If test credentials are provided, sign in automatically
  final testEmail = const String.fromEnvironment('TEST_EMAIL');
  final testPassword = const String.fromEnvironment('TEST_PASSWORD');
  
  if (testEmail.isNotEmpty && testPassword.isNotEmpty) {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
    } catch (e) {
      debugPrint('Failed to sign in with test credentials: $e');
    }
  }

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const VideoFeedScreen(),
          const VideoUploadScreen(),
          ProfileScreen(
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
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_call),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
