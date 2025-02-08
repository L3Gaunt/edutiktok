import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/like_service.dart';
import '../services/view_service.dart';
import '../services/video_upload_service.dart';
import '../screens/video_upload_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) async {
        if (info.visibleFraction > 0.8) {
          if (_isDisposed) {
            _reinitializeController();
          }
          if (_isInitialized && !_controller.value.isPlaying) {
            _controller.play();
            // Record view when video starts playing and hasn't been recorded yet
            if (!_hasRecordedView) {
              try {
                await _viewService.recordView(widget.videoId);
                if (mounted) {
                  setState(() {
                    _hasRecordedView = true;
                  });
                }
              } catch (e) {
                print('Error recording view: $e');
              }
            }
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
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            _isSwipeInProgress = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          setState(() {
            _swipeOffset += details.delta.dx;
            _swipeOffset = _swipeOffset.clamp(-screenWidth, screenWidth);
          });
        },
        onHorizontalDragEnd: (details) {
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
        },
        child: Transform.translate(
          offset: Offset(_swipeOffset, 0),
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
              
              // Swipe overlay indicators
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
            ],
          ),
        ),
      ),
    );
  }
} 