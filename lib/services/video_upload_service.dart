import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Pick video from gallery or camera
  Future<XFile?> pickVideo({required bool fromCamera}) async {
    final XFile? video = await _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 10), // Limit video duration to 10 minutes
    );
    return video;
  }

  // Upload video to Firebase Storage and store metadata in Firestore
  Future<String?> uploadVideo(XFile videoFile, {String? title}) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User must be logged in to upload videos');
      }

      final userId = _auth.currentUser!.uid;
      final timestamp = DateTime.now();
      final videoFileName = 'videos/$userId/${timestamp.millisecondsSinceEpoch}.mp4';
      
      final videoRef = _storage.ref().child(videoFileName);
      
      final uploadTask = videoRef.putFile(
        File(videoFile.path),
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: $progress%');
      });

      // Wait for upload to complete and get download URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Store metadata in Firestore
      await _firestore.collection('videos').add({
        'url': downloadUrl,
        'userId': userId,
        'timestamp': timestamp,
        'title': title,
        'likes': 0,
        'views': 0,
      });
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading video: $e');
      rethrow;
    }
  }
} 