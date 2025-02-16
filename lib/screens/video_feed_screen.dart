import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/video_player_item.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();

  void _handleRecommendationSelected(dynamic recommendation) {
    // Find the index of the recommended video in the current list
    FirebaseFirestore.instance
        .collection('videos')
        .doc(recommendation['id'])
        .get()
        .then((doc) {
          if (doc.exists) {
            // Add the video to the feed and scroll to it
            setState(() {
              // The StreamBuilder will automatically update with the new video
              // Just scroll to the top where the new video will appear
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
            controller: _pageController,
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
                videoId: videos[index].id,
                subtitles: videoData['subtitles'],
                onRecommendationSelected: _handleRecommendationSelected,
              );
            },
          );
        },
      ),
    );
  }
}