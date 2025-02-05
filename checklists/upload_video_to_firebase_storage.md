## Considerations
(None at this time)

## Checklist for Recording and Uploading a Video to Firebase Storage

- [ ] Add Firebase Storage to the project  
  - [ ] Add the firebase_storage dependency ([1](https://docs.flutter.dev/get-started/flutter-for/xamarin-forms-devs#how-do-i-use-firebase-features)).
  - [ ] Run flutter pub add firebase_storage or manually add it to your pubspec.yaml.

- [ ] Set up permissions for camera and microphone access (for video recording)  
  - [ ] Android: Update AndroidManifest.xml with camera and record audio permissions ([2](https://developer.android.com/training/permissions/usage-notes)).

- [ ] Choose how to record or pick a video  
  - [ ] Option A: Use the camera plugin ([3](https://pub.dev/packages/camera)) to record video directly within the app.  
    - [ ] Request camera and microphone permissions.  
    - [ ] Implement camera widget and record functionality.  
  - [ ] Option B: Use the image_picker plugin ([4](https://pub.dev/packages/image_picker)) to pick an existing video or record a new one via the system camera UI.

- [ ] Upload the video file to Firebase Storage  
  - [ ] Get a reference to Firebase Storage.  
  - [ ] Use putFile or putData to upload ([5](https://firebase.google.com/docs/storage/flutter/upload-files)).  
  - [ ] Handle progress, success, and error events.  

- [ ] (Optional) Generate a video preview or thumbnail  
  - [ ] Implement a solution to either generate or pick a thumbnail image for better user experience.

- [ ] Test the flow  
  - [ ] Test on multiple platforms (Android and iOS).  
  - [ ] Verify successful uploads in the Firebase Console, under Storage.
  - [ ] Handle error scenarios (no camera, insufficient permissions, etc.).

## Warnings
- Ensure that video files can be large, so plan for storage costs and potential upload timeouts.  
- Verify you do not commit google-services.json or any private keys to version control.  
- Test on real devices for accurate camera and audio recording behavior.  