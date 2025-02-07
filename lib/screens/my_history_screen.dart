import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/video_player_item.dart';

class MyHistoryScreen extends StatefulWidget {
  const MyHistoryScreen({super.key});

  @override
  State<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends State<MyHistoryScreen> {
  bool _showOnlyLiked = false;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Center(
        child: Text('Please sign in to view your history'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My History'),
        actions: [
          Row(
            children: [
              const Text('Show Liked Only'),
              Switch(
                value: _showOnlyLiked,
                onChanged: (value) {
                  setState(() {
                    _showOnlyLiked = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('views')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final views = snapshot.data?.docs ?? [];
          
          if (views.isEmpty) {
            return const Center(
              child: Text('No videos viewed yet. Start watching some videos!'),
            );
          }

          return FutureBuilder<List<DocumentSnapshot>>(
            future: _getVideoDetails(views, _showOnlyLiked),
            builder: (context, videoSnapshot) {
              if (videoSnapshot.hasError) {
                return Center(child: Text('Error: ${videoSnapshot.error}'));
              }

              if (videoSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final videos = videoSnapshot.data ?? [];

              if (videos.isEmpty) {
                return Center(
                  child: Text(_showOnlyLiked 
                    ? 'No liked videos in your history'
                    : 'No videos in your history'),
                );
              }

              return ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final videoData = videos[index].data() as Map<String, dynamic>;
                  
                  return SizedBox(
                    height: 300, // Adjust based on your needs
                    child: VideoPlayerItem(
                      videoUrl: videoData['url'],
                      title: videoData['title'] ?? '',
                      likes: videoData['likes'] ?? 0,
                      views: videoData['views'] ?? 0,
                      videoId: videos[index].id,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DocumentSnapshot>> _getVideoDetails(
    List<QueryDocumentSnapshot> views,
    bool onlyLiked,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final videoIds = views.map((view) => view.get('videoId') as String).toList();
    final videos = <DocumentSnapshot>[];

    for (final videoId in videoIds) {
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!videoDoc.exists) continue;

      if (onlyLiked) {
        final likeDoc = await FirebaseFirestore.instance
            .collection('likes')
            .doc('${videoId}_${user.uid}')
            .get();

        if (likeDoc.exists) {
          videos.add(videoDoc);
        }
      } else {
        videos.add(videoDoc);
      }
    }

    return videos;
  }
} 