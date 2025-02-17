import 'dart:io';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  
  // Stream controller for upload progress
  final StreamController<double> _uploadProgressController = StreamController<double>.broadcast();
  Stream<double> getUploadProgress() => _uploadProgressController.stream;

  @override
  void dispose() {
    _uploadProgressController.close();
    VideoCompress.cancelCompression();
  }

  // Pick video from gallery or camera
  Future<XFile?> pickVideo({required bool fromCamera}) async {
    final XFile? video = await _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 10), // Limit video duration to 10 minutes
    );
    return video;
  }

  // Compress video before upload
  Future<File?> _compressVideo(String videoPath) async {
    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality, // You can adjust quality as needed
        deleteOrigin: true, // Keep original video
      );
      return mediaInfo?.file;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  // Upload video to Firebase Storage and store metadata in Firestore
  Future<String?> uploadVideo(XFile videoFile, {
    String? title,
    String? replyToVideoId,
  }) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User must be logged in to upload videos');
      }

      // Compress video before upload
      final File? compressedVideo = await _compressVideo(videoFile.path);
      if (compressedVideo == null) {
        throw Exception('Failed to compress video');
      }

      final userId = _auth.currentUser!.uid;
      final timestamp = DateTime.now();
      final videoFileName = 'videos/$userId/${timestamp.millisecondsSinceEpoch}.mp4';
      
      final videoRef = _storage.ref().child(videoFileName);
      
      final uploadTask = videoRef.putFile(
        compressedVideo,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Listen to upload progress and emit to stream
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        _uploadProgressController.add(progress);
      });

      // Wait for upload to complete and get download URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Store metadata in Firestore with auto-generated ID
      final docRef = await _firestore.collection('videos').add({
        'url': downloadUrl,
        'userId': userId,
        'timestamp': timestamp,
        'title': title,
        'likes': 0,
        'views': 0,
        if (replyToVideoId != null) 'replyTo': replyToVideoId,
      });
      
      // Update the document with its ID
      await docRef.update({
        'id': docRef.id,
      });

      // If this is a reply, update the original video's replies count
      if (replyToVideoId != null) {
        await _firestore.collection('videos').doc(replyToVideoId).update({
          'replyCount': FieldValue.increment(1),
        });
      }
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading video: $e');
      rethrow;
    }
  }
} 