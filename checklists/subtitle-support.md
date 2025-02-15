# Subtitle Support Implementation Checklist

## Considerations
- Use the OpenAI Whisper API to generate the subtitles

## Infrastructure Setup
- [ ] Firebase Cloud Functions Environment
  - [ ] Upgrade to Blaze plan if not already done
  - [ ] Set up Node.js environment for Cloud Functions
  - [ ] Install necessary dependencies (ffmpeg, etc.)
  - [ ] Configure Cloud Function memory and timeout settings

## Implementation Tasks

### Cloud Function Setup
- [ ] Create new Firebase Cloud Function
  - [ ] Configure function to trigger on Storage finalize event
  - [ ] Set up proper IAM roles and permissions
  - [ ] Implement error handling and retry logic
  - [ ] Add logging for monitoring and debugging

### Video Processing Pipeline
- [ ] Audio Extraction
  - [ ] Download video to Cloud Function temp storage
  - [ ] Directly pass the video file to the Whisper API for processing
  - [ ] Implement cleanup of temporary files

- [ ] Speech-to-Text Processing
  - [ ] Set up Speech-to-Text API credentials
  - [ ] Configure language detection or selection
  - [ ] Process audio file through Speech-to-Text API
  - [ ] Handle timing information in the transcript

- [ ] Subtitle Generation
  - [ ] Convert transcript to chosen subtitle format
  - [ ] Include proper timing information
  - [ ] Handle special characters and formatting
  - [ ] Validate subtitle file format

### Video Processing
- [ ] Subtitle Overlay
  - [ ] Configure ffmpeg for subtitle burning
  - [ ] Set up proper font and styling
  - [ ] Handle different video resolutions
  - [ ] Optimize processing settings

### Storage and Database
- [ ] Update Firebase Storage
  - [ ] Create new storage path for processed videos
  - [ ] Set up proper security rules
  - [ ] Implement cleanup of original videos if needed

- [ ] Update Firestore Schema
  - [ ] Add subtitle-related fields to video documents
  - [ ] Store processing status and metadata
  - [ ] Add subtitle URL or content field

### Client-Side Implementation
- [ ] Update Video Player
  - [ ] Modify `VideoPlayerItem` widget to support subtitles
  - [ ] Add subtitle toggle controls
  - [ ] Handle subtitle styling and positioning

### Testing
- [ ] Unit Tests
  - [ ] Test Cloud Function components
  - [ ] Validate subtitle generation
  - [ ] Test error handling

- [ ] Integration Tests
  - [ ] Test end-to-end video processing
  - [ ] Verify subtitle synchronization
  - [ ] Test with different video formats and lengths

## Warnings
- Ensure proper error handling in Cloud Functions to prevent infinite retry loops
- Monitor Cloud Function execution time to stay within limits (currently 540s max)
- Watch out for Cloud Function memory usage when processing large videos
- Set up budget alerts for Speech-to-Text API usage
- Consider implementing queue system for multiple video processing
- Test subtitle visibility against different video backgrounds
- Verify subtitle processing doesn't significantly delay video availability
