# Firebase App Distribution Setup

- [x] Install and configure the Firebase CLI
  - [x] Ensure you are logged in to Google via the CLI (run: firebase login)
  - [x] Make sure your CLI is up to date (run: firebase --version)

- [x] Configure Firebase App Distribution in your project
  - [x] Add the Firebase App Distribution Gradle plugin to the android/build.gradle dependencies
  - [x] Apply the plugin in android/app/build.gradle
  - [x] Ensure google-services plugin is also applied

- [PROGRESS] Obtain necessary credentials for distribution
  - [x] Confirm you have a Google service account or the correct user permissions in the Firebase console
  - [ ] (Optional) If using service account authentication, configure a service account key locally

- [PROGRESS] Create tester groups in the Firebase console
  - [ ] Add your own email address (or phone's Google account) as a tester
  - [ ] Add any additional emails or configure tester groups

- [ ] Set up distribution for Android build
  - [ ] Generate an AAB or APK for release (gradle task: assembleRelease or bundleRelease)
  - [ ] Run the Firebase App Distribution upload task (e.g., firebase appdistribution:distribute or gradlew appDistributionUploadRelease)

- [ ] (Optional) Automate distribution flow
  - [ ] Integrate with a CI tool (e.g., GitHub Actions, Bitrise, etc.)
  - [ ] Configure build and distribution steps in your CI pipeline

---

## Warnings
- Make sure your service account key (if used) and google-services.json are not committed to version control  
- Verify testers receive the distribution invite and that they can install the app successfully  
- Test your release on real devices (including your own!) before rolling out to larger groups or production 

## Next Steps
1. ✅ Add the Firebase App Distribution Gradle plugin to android/build.gradle
2. ✅ Apply the plugin in android/app/build.gradle
3. Set up tester groups in the Firebase Console:
   - Go to the Firebase Console > App Distribution
   - Create a new group called "testers"
   - Add your email address as the first tester
4. Generate a release build:
   ```bash
   flutter build apk --release
   ```
5. Upload the build to Firebase App Distribution:
   ```bash
   cd android && ./gradlew appDistributionUploadRelease
   ``` 