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
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  Future<void> _handleVideoUpload(bool fromCamera) async {
    try {
      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Pick video
      final video = await _uploadService.pickVideo(fromCamera: fromCamera);
      if (video == null) {
        setState(() => _isUploading = false);
        return;
      }

      // Upload video
      final downloadUrl = await _uploadService.uploadVideo(video);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully!')),
      );
      
      // Here you could save the downloadUrl to Firestore or navigate to another screen
      
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUploading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%'),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _handleVideoUpload(true),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Record New Video'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _handleVideoUpload(false),
                  icon: const Icon(Icons.video_library),
                  label: const Text('Choose from Gallery'),
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
      ),
    );
  }
} 