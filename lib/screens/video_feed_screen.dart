import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
            itemBuilder: (context, index) {
              final videoData = videos[index].data() as Map<String, dynamic>;
              
              // Preload the next video if it exists
              if (index < videos.length - 1) {
                final nextVideoData = videos[index + 1].data() as Map<String, dynamic>;
                precacheNextVideo(nextVideoData['url']);
              }
              
              return VideoPlayerItem(
                videoUrl: videoData['url'],
                title: videoData['title'] ?? '',
                likes: videoData['likes'] ?? 0,
                views: videoData['views'] ?? 0,
              );
            },
          );
        },
      ),
    );
  }

  void precacheNextVideo(String url) {
    VideoPlayerController.network(
      url,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    ).initialize();
  }
}

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int likes;
  final int views;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.likes,
    required this.views,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isBuffering = true;
  double _bufferingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(
      widget.videoUrl,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );

    try {
      await _controller.initialize();
      _controller.addListener(_videoListener);
      await _controller.setLooping(true);
      
      // Start buffering the video
      await _controller.play();
      await _controller.pause();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    }
  }

  void _videoListener() {
    final value = _controller.value;
    
    // Check if video is buffering
    if (value.isBuffering && mounted) {
      setState(() {
        _isBuffering = true;
      });
    } else if (!value.isBuffering && _isBuffering && mounted) {
      setState(() {
        _isBuffering = false;
      });
    }
    
    // Update buffering progress
    if (value.buffered.isNotEmpty && mounted) {
      final bufferEnd = value.buffered.last.end;
      final duration = value.duration;
      setState(() {
        _bufferingProgress = bufferEnd.inMilliseconds / duration.inMilliseconds;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          _controller.play();
        } else {
          _controller.pause();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized)
            GestureDetector(
              onTap: () {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              },
              child: VideoPlayer(_controller),
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Buffering indicator
          if (_isBuffering)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    '${(_bufferingProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          
          // Video Info Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.title.isNotEmpty)
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.likes}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.views}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Buffering progress bar
          if (_isBuffering)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _bufferingProgress,
                backgroundColor: Colors.grey.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }
} 