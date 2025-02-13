# Checklists

## Considerations
[x] Decide on the buffer eviction policy (e.g., LRU, time-based, size-based). <- LRU for now
[x] Decide on the synchronization method for concurrent buffer access (e.g., locking mechanisms vs. asynchronous queues). <- only one writer for now, so it's not so important
[x] Decide on the specific mechanism for logging and retrieving client history. <- just put references to the buffers in an array for now

## Tasks
- [x] **Buffer Manager Module (`bufferManager.js`):**
  - [x] Implement `createBuffer(clientId)` to initialize a new buffer.
  - [x] Implement `appendPacket(clientId, packet)` to continuously add incoming packets.
  - [x] Implement `markBufferComplete(clientId)` to finalize a buffer when recording stops.
  - [ ] Implement `getBufferedData(clientId, offset)` to retrieve packets starting from a given offset. <- only need offset 0
  - [x] Implement an eviction policy to remove least relevant or old buffers.
- [x] **Server-Side Updates (`server.js`):**
  - [x] Add WebSocket message handler for `"startRecording"` to initialize recording buffers.
  - [x] Add WebSocket message handler for `"stopRecording"` to mark buffers as complete.
  - [x] Add WebSocket message handler for `"consumeRecording"` to serve buffered data on demand.
  - [x] Intercept media packets during live streaming and duplicate them to the Buffer Manager.
- [PROGRESS] **Client-Side Enhancements (`client.js`):**
  - [x] We want one screen that plays the currently streaming recording, and another, smaller one for my own webcam.
  - [x] Add UI controls for "Start Recording" and "Stop Recording". <- They should be one button that changes state
  - [x] On "Start Recording", send a `"startRecording"` message to the server and begin transmitting.
  - [x] On "Stop Recording", send a `"stopRecording"` message.
  - [ ] Seamlessly transition the video element from live streaming to buffered playback using data from `"consumeRecording"`. <- always go via buffer of currently chosen recording
  - [ ] Implement a history logging mechanism to track previously viewed recordings.
- [x] **Code Organization:**
  - [x] Monitor file sizes and refactor modules if any file (client or server) exceeds 250 lines.

## Warnings
- **Memory Overhead:**  
  Continuously buffering media packets in RAM can lead to high memory usage. A robust eviction policy is critical.
- **Concurrency Issues:**  
  Ensure safe concurrent read and write access to buffers to prevent race conditions.
- **Seamless Transition Handling:**  
  Proper synchronization and timestamp management are required to maintain a continuous, unnoticeable switch from live to buffered content.
- **Playback Implementation:**
  We still need to implement the actual playback mechanism for the buffered recordings in the client.