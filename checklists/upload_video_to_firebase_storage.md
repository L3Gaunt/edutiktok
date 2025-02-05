## Considerations
- Project must be on the Blaze (pay-as-you-go) pricing plan to use Cloud Storage ✓
- If you're new to Firebase and Google Cloud, you may be eligible for a $300 credit
- Firebase Storage configuration (bucket and rules) was done manually in Firebase Console (not reflected in git)

## Checklist for Recording and Uploading a Video to Firebase Storage

- [x] Add Firebase Storage to the project  
  - [x] Add the firebase_storage dependency ([1](https://docs.flutter.dev/get-started/flutter-for/xamarin-forms-devs#how-do-i-use-firebase-features)).
  - [x] Run flutter pub add firebase_storage or manually add it to your pubspec.yaml.

- [x] Set up Firebase Storage in Firebase Console
  - [x] Initialize Firebase Storage in the Firebase Console
  - [x] Choose a storage bucket location ("edutiktok-storage-bucket")
  - [x] Upgrade to Blaze (pay-as-you-go) plan if not already done
  - [x] Configure security rules to allow authenticated users to upload

- [x] Set up permissions for camera and microphone access (for video recording)  
  - [x] Android: Update AndroidManifest.xml with camera and record audio permissions ([2](https://developer.android.com/training/permissions/usage-notes)).

- [x] Choose how to record or pick a video  
  - [x] Option B: Use the image_picker plugin ([4](https://pub.dev/packages/image_picker)) to pick an existing video or record a new one via the system camera UI.

- [x] Upload the video file to Firebase Storage  
  - [x] Get a reference to Firebase Storage.  
  - [x] Use putFile or putData to upload ([5](https://firebase.google.com/docs/storage/flutter/upload-files)).  
  - [x] Handle progress, success, and error events.  

- [ ] (Optional) Generate a video preview or thumbnail  
  - [ ] Implement a solution to either generate or pick a thumbnail image for better user experience.

- [PROGRESS] Test the flow  
  - [x] Basic upload functionality verified
  - [x] Verify successful uploads in the Firebase Console, under Storage.
  - [ ] Handle error scenarios (no camera, insufficient permissions, etc.).

## Warnings
- Ensure that video files can be large, so plan for storage costs and potential upload timeouts.  
- Verify you do not commit google-services.json or any private keys to version control.  
- Test on real devices for accurate camera and audio recording behavior.  
- Make sure to update the security rules for production to be more restrictive based on your app's requirements.  
- Consider setting up budget alerts in the Google Cloud Console to monitor storage costs.  