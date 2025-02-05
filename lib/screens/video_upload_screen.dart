import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/video_upload_service.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final VideoUploadService _uploadService = VideoUploadService();
  final TextEditingController _titleController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  XFile? _selectedVideo;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(bool fromCamera) async {
    try {
      final video = await _uploadService.pickVideo(fromCamera: fromCamera);
      if (video != null) {
        setState(() {
          _selectedVideo = video;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleVideoUpload() async {
    if (_selectedVideo == null) {
      setState(() => _errorMessage = 'Please select a video first');
      return;
    }

    try {
      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Upload video with title
      final downloadUrl = await _uploadService.uploadVideo(
        _selectedVideo!,
        title: _titleController.text.trim(),
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully!')),
      );
      
      // Clear form
      setState(() {
        _selectedVideo = null;
        _titleController.clear();
      });
      
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedVideo != null) ...[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Video selected: ${_selectedVideo!.name}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Video Title',
                  hintText: 'Enter a title for your video',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isUploading,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isUploading ? null : _handleVideoUpload,
                child: const Text('Upload Video'),
              ),
            ] else ...[
              const Text(
                'Choose how to add your video:',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _pickVideo(true),
                icon: const Icon(Icons.videocam),
                label: const Text('Record New Video'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _pickVideo(false),
                icon: const Icon(Icons.video_library),
                label: const Text('Choose from Gallery'),
              ),
            ],
            if (_isUploading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
} 