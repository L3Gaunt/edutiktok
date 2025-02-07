import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Records a view for a video
  Future<void> recordView(String videoId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to record video views');
    }

    final userId = _auth.currentUser!.uid;
    final viewDoc = _firestore
        .collection('views')
        .doc('${videoId}_$userId');
    
    final videoRef = _firestore.collection('videos').doc(videoId);

    try {
      await _firestore.runTransaction((transaction) async {
        final viewSnapshot = await transaction.get(viewDoc);
        final videoSnapshot = await transaction.get(videoRef);

        if (!videoSnapshot.exists) {
          throw Exception('Video not found');
        }

        if (!viewSnapshot.exists) {
          // Record the view
          transaction.set(viewDoc, {
            'userId': userId,
            'videoId': videoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          transaction.update(videoRef, {
            'views': FieldValue.increment(1),
          });
        }
        // If view already exists, we don't need to do anything
      });
    } catch (e) {
      print('Error recording view: $e');
      rethrow;
    }
  }

  /// Check if a video has been viewed by the current user
  Future<bool> hasUserViewedVideo(String videoId) async {
    if (_auth.currentUser == null) {
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final viewDoc = await _firestore
          .collection('views')
          .doc('${videoId}_$userId')
          .get();
      
      return viewDoc.exists;
    } catch (e) {
      print('Error checking view status: $e');
      return false;
    }
  }
} 