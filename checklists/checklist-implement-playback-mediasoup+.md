# Considerations

*(None at this time.)*

# Checklist: Required Code Changes

- [ ] **Server: BufferManager**  
  - [ ] Store incoming RTP data fully (not just RTCP) for recording.  
  - [ ] Implement methods to stop the recording properly and finalize the buffer.

- [ ] **Server: Playback Flow**  
  - [ ] Use the existing consumer transport to feed recorded packets to client without manual "handleRecordingStream" on the client.  
  - [ ] Ensure transitions between recordings are handled by the server, with minimal client interaction.

- [ ] **Client: Recording Buttons**  
  - [ ] Keep camera/transport open even when not recording, only produce to server (i.e., send media) when "Start Recording" is pressed.  
  - [ ] Stop producing and finalize buffer on "Stop Recording."

- [ ] **Client: Playback**  
  - [ ] Automatically receive recorded packets from server (no extra logic to handle transitions).

- [ ] **Cleanup Existing Code**  
  - [ ] Remove references to "handleRecordingData" if the server sends packets through the same consumer.  
  - [ ] Remove or refactor code that tries to produce video as soon as the page loads, if undesired.

---