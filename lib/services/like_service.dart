import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LikeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Toggles like status for a video
  Future<bool> toggleLike(String videoId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to like videos');
    }

    final userId = _auth.currentUser!.uid;
    final likeDoc = _firestore
        .collection('likes')
        .doc('${videoId}_$userId');
    
    final videoRef = _firestore.collection('videos').doc(videoId);

    bool isLiked = false;

    try {
      return await _firestore.runTransaction((transaction) async {
        final likeSnapshot = await transaction.get(likeDoc);
        final videoSnapshot = await transaction.get(videoRef);

        if (!videoSnapshot.exists) {
          throw Exception('Video not found');
        }

        if (!likeSnapshot.exists) {
          // Like the video
          transaction.set(likeDoc, {
            'userId': userId,
            'videoId': videoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          transaction.update(videoRef, {
            'likes': FieldValue.increment(1),
          });
          
          isLiked = true;
        } else {
          // Unlike the video
          transaction.delete(likeDoc);
          
          transaction.update(videoRef, {
            'likes': FieldValue.increment(-1),
          });
          
          isLiked = false;
        }
        
        return isLiked;
      });
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  /// Check if a video is liked by the current user
  Future<bool> isVideoLiked(String videoId) async {
    if (_auth.currentUser == null) {
      return false;
    }

    try {
      final userId = _auth.currentUser!.uid;
      final likeDoc = await _firestore
          .collection('likes')
          .doc('${videoId}_$userId')
          .get();
      
      return likeDoc.exists;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }
} 