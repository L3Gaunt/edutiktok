import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/video_player_item.dart';

class VideoFeedScreen extends StatelessWidget {
  const VideoFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final videos = snapshot.data?.docs ?? [];
          
          if (videos.isEmpty) {
            return const Center(
              child: Text('No videos yet. Be the first to upload!'),
            );
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            pageSnapping: true,
            itemBuilder: (context, index) {
              final videoData = videos[index].data() as Map<String, dynamic>;
              
              return VideoPlayerItem(
                videoUrl: videoData['url'],
                title: videoData['title'] ?? '',
                likes: videoData['likes'] ?? 0,
                views: videoData['views'] ?? 0,
                videoId: videoData['id'] ?? '',
              );
            },
          );
        },
      ),
    );
  }
}