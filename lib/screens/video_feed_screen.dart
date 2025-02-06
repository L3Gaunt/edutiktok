import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/like_service.dart';

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

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int likes;
  final int views;
  final String videoId;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.likes,
    required this.views,
    required this.videoId,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isBuffering = true;
  double _bufferingProgress = 0.0;
  final LikeService _likeService = LikeService();
  bool _isLiked = false;
  bool _isLikeLoading = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    final isLiked = await _likeService.isVideoLiked(widget.videoId);
    if (mounted) {
      setState(() {
        _isLiked = isLiked;
      });
    }
  }

  Future<void> _handleLikePress() async {
    if (_isLikeLoading) return;

    setState(() {
      _isLikeLoading = true;
    });

    try {
      final isLiked = await _likeService.toggleLike(widget.videoId);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;
    
    try {
      _controller = VideoPlayerController.network(
        widget.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      _controller.addListener(() {
        final error = _controller.value.errorDescription;
        if (error != null) {
          print('Video player error: $error');
          _disposeController();
          if (mounted) {
            _reinitializeController();
          }
        }
      });

      await _controller.initialize();
      
      if (mounted && !_isDisposed) {
        _controller.addListener(_videoListener);
        await _controller.setLooping(true);
        
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isBuffering = false;
          _isInitialized = false;
        });
      }
    }
  }

  void _disposeController() {
    if (!_isDisposed) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
      _isDisposed = true;
      _isInitialized = false;
    }
  }

  void _reinitializeController() {
    if (_isDisposed) {
      _isDisposed = false;
      _initializeVideo();
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
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.8) {
          if (_isDisposed) {
            _reinitializeController();
          }
          if (_isInitialized && !_controller.value.isPlaying) {
            _controller.play();
          }
        } else {
          if (_isInitialized && _controller.value.isPlaying) {
            _controller.pause();
          }
          if (info.visibleFraction < 0.2) {
            _disposeController();
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && !_isDisposed)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxWidth / _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_isBuffering || !_isInitialized)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _handleLikePress,
                    iconSize: 40,
                    padding: const EdgeInsets.all(12),
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.likes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.views} views',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 