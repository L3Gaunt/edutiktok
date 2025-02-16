import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/like_service.dart';
import '../services/view_service.dart';
import '../services/video_upload_service.dart';
import '../screens/video_upload_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int likes;
  final int views;
  final String videoId;
  final String? subtitles;
  final Function(dynamic)? onRecommendationSelected;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.likes,
    required this.views,
    required this.videoId,
    this.subtitles,
    this.onRecommendationSelected,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isBuffering = true;
  double _bufferingProgress = 0.0;
  final LikeService _likeService = LikeService();
  final ViewService _viewService = ViewService();
  bool _isLiked = false;
  bool _isLikeLoading = false;
  bool _isDisposed = false;
  bool _hasRecordedView = false;
  final VideoUploadService _uploadService = VideoUploadService();
  bool _isUploading = false;
  String? _uploadStatus;
  bool _showSubtitles = true;
  List<SrtSubtitle>? _parsedSubtitles;
  List<dynamic>? _recommendations;
  bool _showRecommendations = false;

  // Swipe-related variables
  late AnimationController _swipeController;
  double _swipeOffset = 0.0;
  bool _isSwipeInProgress = false;
  static const double _swipeThreshold = 0.3; // 30% of screen width

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkLikeStatus();
    if (widget.subtitles != null) {
      _parsedSubtitles = parseSrtSubtitles(widget.subtitles!);
    }
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() => setState(() {}));
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

    // Check if video ended
    if (value.position >= value.duration) {
      setState(() {
        _showRecommendations = true;
      });
    }
  }

  @override
  void dispose() {
    _disposeController();
    _swipeController.dispose();
    super.dispose();
  }

  void _handleSwipeComplete(bool isReply) async {
    if (isReply) {
      // Pause current video
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
      
      try {
        // Pick and upload reply video
        final video = await _uploadService.pickVideo(fromCamera: true);
        if (video != null && mounted) {
          setState(() {
            _isUploading = true;
            _uploadStatus = 'Starting upload...';
          });

          // Upload the video with reference to original
          final uploadTask = _uploadService.uploadVideo(
            video,
            title: 'Reply to: ${widget.title}',
            replyToVideoId: widget.videoId,
          );

          // Listen to upload progress
          _uploadService.getUploadProgress().listen((progress) {
            if (mounted) {
              setState(() {
                _uploadStatus = 'Uploading: ${progress.toStringAsFixed(0)}%';
              });
            }
          });

          await uploadTask;

          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadStatus = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video reply uploaded successfully!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadStatus = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading reply: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    // Reset swipe state
    setState(() {
      _isSwipeInProgress = false;
      _swipeOffset = 0;
    });
  }

  Future<void> _fetchRecommendations() async {
    try {
      print('Fetching recommendations for video: ${widget.videoId}');
      
      final functions = FirebaseFunctions.instance;
      final result = await functions
          .httpsCallable('getVideoRecommendations')
          .call({
        'videoId': widget.videoId,
        'description': widget.title, // Using title as description for now
      });
      
      if (mounted) {
        setState(() {
          _recommendations = result.data['recommendations'];
        });
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
    }
  }

  void _handleRecommendationTap(dynamic recommendation) {
    setState(() {
      _showRecommendations = false;
    });
    
    if (widget.onRecommendationSelected != null) {
      widget.onRecommendationSelected!(recommendation);
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) async {
    print('Visibility changed: ${info.visibleFraction}');
    if (info.visibleFraction > 0.8) {
      print('Video highly visible (>80%)');
      print('View recorded successfully, fetching recommendations');
      await _fetchRecommendations();
      if (_isDisposed) {
        print('Controller was disposed, reinitializing');
        _reinitializeController();
      }
      if (_isInitialized && !_controller.value.isPlaying) {
        print('Starting video playback');
        _controller.play();
        // Record view when video starts playing and hasn't been recorded yet
        if (!_hasRecordedView) {
          print('First time viewing, recording view and fetching recommendations');
          try {
            await _viewService.recordView(widget.videoId);
            if (mounted) {
              setState(() {
                _hasRecordedView = true;
              });
            }
          } catch (e) {
            print('Error recording view or fetching recommendations: $e');
          }
        } else {
          print('View already recorded, skipping view recording and recommendations');
        }
      } else {
        print('Video not ready to play: initialized=${_isInitialized}, playing=${_controller.value.isPlaying}');
      }
    } else {
      print('Video not highly visible (<80%)');
      if (_isInitialized && _controller.value.isPlaying) {
        _controller.pause();
      }
      if (info.visibleFraction < 0.2) {
        _disposeController();
      }
    }
  }

  void _handleTap(TapUpDetails details) {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _swipeOffset += details.delta.dx;
      _swipeOffset = _swipeOffset.clamp(-screenWidth, screenWidth);
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final swipePercentage = _swipeOffset.abs() / screenWidth;
    
    if (swipePercentage > _swipeThreshold) {
      _handleSwipeComplete(_swipeOffset > 0);
    } else {
      // Reset position if threshold not met
      setState(() {
        _isSwipeInProgress = false;
        _swipeOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoId),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        onTapUp: _handleTap,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              if (_isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              if (_parsedSubtitles != null && _showSubtitles)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      _getCurrentSubtitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_isSwipeInProgress)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          _swipeOffset < 0 
                            ? Colors.red.withOpacity((_swipeOffset.abs() / MediaQuery.of(context).size.width) * 0.5)
                            : Colors.transparent,
                          Colors.transparent,
                          _swipeOffset > 0
                            ? Colors.blue.withOpacity((_swipeOffset.abs() / MediaQuery.of(context).size.width) * 0.5)
                            : Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_swipeOffset < 0)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Icon(
                              Icons.close,
                              color: Colors.white.withOpacity((_swipeOffset.abs() / MediaQuery.of(context).size.width)),
                              size: 48,
                            ),
                          ),
                        if (_swipeOffset > 0)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Icon(
                              Icons.video_camera_back,
                              color: Colors.white.withOpacity((_swipeOffset.abs() / MediaQuery.of(context).size.width)),
                              size: 48,
                            ),
                          ),
                      ],
                    ),
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
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: null,
                        iconSize: 40,
                        padding: const EdgeInsets.all(12),
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.white,
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
                        '${widget.views}',
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
                  ],
                ),
              ),

              // Upload status indicator
              if (_isUploading && _uploadStatus != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _uploadStatus!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: IconButton(
                  icon: Icon(
                    _showSubtitles ? Icons.subtitles : Icons.subtitles_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSubtitles = !_showSubtitles;
                    });
                  },
                ),
              ),

              if (_showRecommendations && _recommendations != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Recommended Videos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _recommendations!.length,
                            itemBuilder: (context, index) {
                              final recommendation = _recommendations![index];
                              return ListTile(
                                onTap: () => _handleRecommendationTap(recommendation),
                                title: Text(
                                  recommendation['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  recommendation['description'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${recommendation['likes']} likes',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      '${recommendation['views']} views',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentSubtitle() {
    if (_parsedSubtitles == null || !_controller.value.isPlaying) {
      return '';
    }
    
    final currentTime = _controller.value.position;
    
    for (final subtitle in _parsedSubtitles!) {
      if (currentTime >= subtitle.startTime && currentTime <= subtitle.endTime) {
        return subtitle.text;
      }
    }
    
    return '';
  }
}

class SrtSubtitle {
  final Duration startTime;
  final Duration endTime;
  final String text;

  SrtSubtitle(this.startTime, this.endTime, this.text);
}

List<SrtSubtitle> parseSrtSubtitles(String srtContent) {
  final subtitles = <SrtSubtitle>[];
  final blocks = srtContent.trim().split('\n\n');

  for (final block in blocks) {
    final lines = block.split('\n');
    if (lines.length < 3) continue;

    final timeRange = lines[1].split(' --> ');
    if (timeRange.length != 2) continue;

    final startTime = _parseSrtTime(timeRange[0]);
    final endTime = _parseSrtTime(timeRange[1]);
    final text = lines.sublist(2).join('\n');

    subtitles.add(SrtSubtitle(startTime, endTime, text));
  }

  return subtitles;
}

Duration _parseSrtTime(String timeStr) {
  final parts = timeStr.trim().split(':');
  if (parts.length != 3) return Duration.zero;

  final seconds = parts[2].split(',');
  if (seconds.length != 2) return Duration.zero;

  return Duration(
    hours: int.parse(parts[0]),
    minutes: int.parse(parts[1]),
    seconds: int.parse(seconds[0]),
    milliseconds: int.parse(seconds[1]),
  );
} 