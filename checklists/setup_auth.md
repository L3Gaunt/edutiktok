# Firebase Auth Integration Checklist

- [x] Install and configure Firebase Auth package for Flutter. ([1](https://docs.flutter.dev/data-and-backend/firebase))
- [x] Create a new Firebase project (if none exists).  
- [x] Prepare the app for Firebase integration:  
  - [x] Add the Firebase SDK to the project.  
  - [x] Run firebase init or flutterfire configure to set up the project.
  - [x] Add google-services.json to .gitignore
- [ ] Set up FirebaseUI Auth:
  - [x] Install firebase_ui_auth package
  - [ ] Add SocialIcons font to pubspec.yaml for profile screens
  - [ ] Initialize FirebaseUI Auth in the app
- [ ] Implement Email/Password authentication:  
  - [ ] Enable Email/Password sign-in in Firebase Console
  - [ ] Add SignInScreen to your app
  - [ ] Add profile screen (optional)
  - [ ] Customize theme to match your app (optional)
- [ ] Implement Email Link authentication (optional):  
  - [ ] Enable Email Link sign-in in Firebase console
  - [ ] Configure EmailLinkAuthProvider
  - [ ] Add deep link handling
- [ ] Implement GitHub OAuth (optional):  
  - [ ] Create GitHub OAuth App and get credentials
  - [ ] Enable GitHub sign-in in Firebase Console
  - [ ] Configure OAuthProvider with GitHub
- [ ] Set up testing:  
  - [ ] Test sign-in flow
  - [ ] Test sign-out flow
  - [ ] Test error states
  - [ ] Test deep links (if using Email Link auth)

---

## Warnings

- Make sure google-services.json is never committed to version control
- Test the authentication flow on real devices before releasing
- FirebaseUI Auth provides a standard Material Design interface - make sure it matches your app's design language
- Some authentication methods have platform limitations (but all work on Android)

https://firebase.google.com/docs/auth/android/firebaseui?authuser=0