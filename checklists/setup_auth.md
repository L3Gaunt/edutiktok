# Firebase Auth Integration Checklist

- [x] Install and configure Firebase Auth package for Flutter. ([1](https://docs.flutter.dev/data-and-backend/firebase))
- [x] Create a new Firebase project (if none exists).  
- [x] Prepare the app for Firebase integration:  
  - [x] Add the Firebase SDK to the project.  
  - [x] Run firebase init or flutterfire configure to set up the project.
  - [x] Add google-services.json to .gitignore
- [ ] Implement Email/Password authentication.  
  - [ ] Enable Email/Password sign-in in Firebase Console
  - [ ] Implement sign-up, sign-in, and sign-out flows.  
  - [ ] Handle possible authentication errors.
- [ ] Implement Email Link authentication ("secret link").  
  - [ ] Enable Email Link sign-in in Firebase console.  
  - [ ] Send the link to the user's email.  
  - [ ] Handle deep link to complete sign-in.
- [ ] Implement GitHub OAuth provider.  
  - [ ] Create GitHub OAuth App and get credentials
  - [ ] Enable GitHub sign-in in Firebase Console and configure OAuth credentials
  - [ ] Implement sign-in flow with GitHub Auth.  
  - [ ] Handle OAuth callback in the app.
- [ ] Set up integration tests for end-to-end authentication flows.  
  - [ ] Create integration tests for Email/Password.  
  - [ ] Create integration tests for Email Link sign-in.  
  - [ ] Create integration tests for GitHub login.  
  - [ ] Mock Firebase Auth for testing. ([2](https://docs.flutter.dev/testing/integration-tests))

---

## Warnings

- Make sure google-services.json is never committed to version control
- Thoroughly test the sign-in flows on multiple devices and platforms to ensure consistent user experience across all channels.

