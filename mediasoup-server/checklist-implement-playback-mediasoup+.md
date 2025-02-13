# Checklist: Required Code Changes

## Completed
- [x] **Server: BufferManager**  
  - [x] Store incoming RTP data fully (implemented in `BufferManager.js` with `appendRtpData`)  
  - [x] Implement methods to stop recording properly and finalize buffer (implemented with `markBufferComplete`)

- [x] **Server: Code Organization**  
  - [x] Split server code into modules under 250 lines
  - [x] Create separate managers for MediaSoup, Buffer, and WebSocket handling
  - [x] Implement proper cleanup and resource management

- [x] **Client: Recording Buttons**  
  - [x] Only start streaming when "Start Recording" is pressed
  - [x] Stop streaming and finalize buffer on "Stop Recording"

## In Progress
- [PROGRESS] **Server: Playback Flow**  
  - [x] Use existing consumer transport for recorded packets
  - [ ] Test and verify smooth transitions between recordings
  - [ ] Implement error recovery for failed recordings

- [PROGRESS] **Client: Playback**  
  - [x] Set up automatic packet receiving from server
  - [ ] Implement proper RTP to media segment conversion
  - [ ] Add buffering for smooth playback
  - [ ] Handle codec negotiation for different browser support

## Remaining Tasks
- [ ] **Testing & Validation**  
  - [ ] Add unit tests for BufferManager
  - [ ] Add integration tests for recording flow
  - [ ] Test with different browsers and devices
  - [ ] Verify memory usage during long recordings

- [ ] **Performance Optimization**  
  - [ ] Implement chunked recording for large files
  - [ ] Add compression for stored RTP data
  - [ ] Optimize memory usage for multiple concurrent recordings

## Warnings
- Using both `producer.on('rtp')` and `producer.on('rtcp')` for complete packet capture, but need to verify this catches all necessary data
- Memory usage needs monitoring as RTP buffers can grow large during long recordings
- Browser compatibility for MediaSource API and codecs needs testing
- Session renegotiation between recordings needs careful handling to prevent connection issues

## Considerations
- Consider implementing a cleanup routine for old recordings
- May need to implement a maximum recording duration to prevent memory issues
- Consider adding progress indicators for long recordings
- May need to implement fallback playback method for unsupported browsers

---

## Warnings
- Using only `producer.on('rtcp')` in MediaSoup may not capture all media data needed for a full recording. You might need a different hook or approach (e.g., a custom SFU pipeline or direct rtp listener) to get all packets for playback.  
- Be aware of session renegotiation if you stop and restart the producer for each recording. A stable connection flow is necessary. 