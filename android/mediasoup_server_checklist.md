# Detailed Checklist for Mediasoup Server Setup with Buffering, Dynamic Rerouting, and Firebase Auth Integration

## Phase 1: Minimal Working Video Streaming

### Basic Project Setup
- [x] **Initialize the Project**
  - [x] Run `npm init -y` (if not already done)
  - [x] Install core dependencies:
    - [x] `npm install mediasoup@3`
    - [x] `npm install express` (needed for signaling server)
    - [x] `npm install ws` (for WebSocket handling)

### Minimal Network Setup
- [PROGRESS] **Basic NAT Traversal**
  - [x] Configure public STUN server (Google's stun:stun.l.google.com:19302)
  - [x] Set up basic port ranges for WebRTC traffic (10000-10100)
  - [x] Configure basic IP announcements (using 0.0.0.0 with 127.0.0.1 for development)

### Core Mediasoup Setup
- [x] **Setup Basic Routing**
  - [x] Create mediasoup worker (handles WebRTC connections and packet routing)
  - [x] Create one router instance for managing WebRTC transports
  - [x] Configure basic routing policies (implemented in server.js)
- [x] **Basic Transport Setup**
  - [x] Create WebRTC transport for sender (broadcaster)
  - [x] Create WebRTC transport for receiver (viewer)
  - [x] Structure transport creation to support future dynamic routing
- [x] **Basic Signaling**
  - [x] Implement WebSocket connection
  - [x] Handle basic "connect" event
  - [x] Handle basic "produce" event for sender
  - [x] Handle basic "consume" event for receiver
  - [x] Design message protocol to support future features (rooms, switching, etc.)

### Media Flow Setup
- [x] **Basic Producer/Consumer Management**
  - [x] Implement producer creation and tracking
  - [x] Implement consumer creation and tracking
  - [x] Design producer/consumer relationship to support future dynamic switching
  - [x] Add placeholder for stream selection logic (even if initially just 1:1)

### Test Basic Streaming
- [PROGRESS] **Verify Connection**
  - [x] Test device-to-server connection (WebSocket setup complete)
  - [ ] Verify video stream from sender
  - [ ] Verify receiver can view stream
  - [ ] Test basic stream selection mechanism

## Phase 2: Enhanced Features

### Buffering Module
- [ ] **Design and Implement an In-Memory Buffer**
  - [ ] Create data structure for utterance/video clip storage
  - [ ] Implement basic recording of media chunks
- [ ] **Basic Buffer Management**
  - [ ] Monitor memory usage
  - [ ] Implement simple eviction strategy

### Enhanced Network Configuration
- [ ] **Production NAT Traversal**
  - [ ] Set up TURN server (coturn)
  - [ ] Configure TURN authentication
  - [ ] Add full ICE configuration
- [ ] **Advanced Network Settings**
  - [ ] Configure firewall rules
  - [ ] Optimize port ranges
  - [ ] Enhanced IP announcements

## Phase 3: Scale and Optimize

### Advanced Mediasoup Features
- [ ] **Scale Workers and Routers**
  - [ ] Implement multiple workers
  - [ ] Add multiple routers for different "rooms"
- [ ] **Enhanced Media Handling**
  - [ ] Implement dynamic producer switching
  - [ ] Add stream quality management

### Recommendation System
- [ ] **Basic Random Routing**
  - [ ] Implement random stream selection
  - [ ] Basic stream switching logic
- [ ] **Enhanced Recommendation** (Future)
  - [ ] Implement actual recommendation algorithm
  - [ ] Add user preference handling

## Future Considerations
- [ ] Authentication and Authorization (Firebase)
- [ ] Advanced buffering strategies
- [ ] Machine learning-based recommendations
- [ ] Production monitoring and logging

## Warnings
- Initial setup focuses on functionality over security - add security measures before production
- Basic STUN setup may not work for all network configurations
- Memory usage needs monitoring even in basic setup
- CPU monitoring is important:
  - Each worker (thread) handles encryption/decryption for its streams
  - Monitor CPU usage per worker
  - Plan to scale horizontally (more workers) when reaching ~20 streams per worker
  - Hardware acceleration (AES-NI) should be available on the server
- WebSocket connection needs proper error handling and reconnection logic
- Consider implementing rate limiting for WebSocket connections to prevent DoS attacks
- Ensure proper cleanup of resources when peers disconnect
- For production, replace the announcedIp with actual public IP
- Consider implementing heartbeat mechanism for WebSocket connections
- Add proper error handling for all WebSocket messages

# Detailed Checklist for Mediasoup Server Setup with Buffering, Dynamic Rerouting, and Firebase Auth Integration

## Considerations
- [ ] Decide on the recommendation system's architecture and algorithm (e.g., rules-based vs. machine learning approach). <- first get something to work, then do ML/recommendation
- [ ] Define the maximum in-memory buffer size/duration and eviction strategy to prevent RAM overflow. <- maximal duration of one utterance: 15 seconds, max total buffer size: 1 GB
- [ ] Evaluate how to handle partial utterance streaming (e.g., starting playback while the speaker is still talking vs. waiting for a complete segment). <- start playing back from buffer as soon as speaker starts talking
- [x] Determine the signaling strategy and whether any custom protocols are needed for real-time dynamic switching. <- Using standard WebSocket protocol with JSON messages for transport setup and stream management
- [x] Clarify role-based permissions for producers vs. consumers and any additional security considerations. <- Starting without auth, will add Firebase Auth integration later when core functionality is working

## Checklist

### Project Setup
- [ ] **Initialize the Project**
  - [x] Run `npm init -y` (if not already done).
  - [ ] Install mediasoup and necessary dependencies:
    - [x] `npm install mediasoup@3`
    - [ ] Install required libraries:
      - [ ] `npm install express` (needed for signaling server)
      - [ ] `npm install ws` (for WebSocket handling)
      - [ ] Additional libraries as needed later

### Network Configuration
- [ ] **Configure NAT Traversal**
  - [ ] Set up STUN server configuration
    - [ ] Either use public STUN servers (e.g., Google's stun:stun.l.google.com:19302)
    - [ ] Or set up your own STUN server
  - [ ] Set up TURN server (required for reliable NAT traversal)
    - [ ] Deploy TURN server (e.g., coturn)
    - [ ] Configure authentication for TURN
  - [ ] Add ICE configuration to mediasoup WebRtcTransport options
- [ ] **Network Settings**
  - [ ] Configure proper IP announcements for WebRTC
  - [ ] Set up port ranges for media transmission
  - [ ] Configure firewall rules to allow WebRTC traffic

### Mediasoup Server Basic Setup
- [ ] **Create Mediasoup Workers and Routers**
  - [ ] Set up one or more mediasoup workers using `mediasoup.createWorker()`.
  - [ ] For each worker, create one or more routers for handling different "rooms" or conferences.
- [ ] **Setup WebRTC Transports**
  - [ ] Create send transports (for broadcasters/speakers) using `router.createWebRtcTransport()`.
  - [ ] Create receive transports (for viewers) similarly.
- [ ] **Implement the Signaling Layer**
  - [ ] Develop endpoints to manage connection establishment.
  - [ ] Handle events such as "connect", "produce", and "consume" for proper coordination between clients and the server.

### Media Production and Consumption
- [ ] **Implement Media Production**
  - [ ] Establish producers on the server using `transport.produce()` when a client sends media.
- [ ] **Implement Media Consumption**
  - [ ] Establish consumers on the server using `transport.consume()` so that viewers can receive streams.

### Buffering Module
- [ ] **Design and Implement an In-Memory Buffer**
  - [ ] Create a data structure to record each new utterance/video clip.
  - [ ] Continuously record incoming media chunks into this buffer.
- [ ] **Manage Buffer Size**
  - [ ] Monitor memory usage of the buffer.
  - [ ] Implement an eviction strategy to remove old utterances and prevent RAM overflow.
- [ ] **Testing the Buffer**
  - [ ] Test buffer performance under simulated high-load conditions.

### Recommendation System Integration
- [ ] **Develop and Integrate Recommendation Logic** <- right now just randomly stream things, think about recommendation later
  - [ ] Create a module that analyzes buffered media based on user preferences, context, or other criteria.
  - [ ] Develop an API/function to decide which utterance should be played back for each viewer.
  - [ ] Integrate this recommendation mechanism with the dynamic rerouting of streams.

### Dynamic Rerouting / Partial Streaming
- [ ] **Implement Dynamic Rerouting**
  - [ ] Enable starting playback on a partially received utterance.
  - [ ] Dynamically route or remap media producers to consumers based on real-time recommendations.
- [ ] **Error Handling and Synchronization**
  - [ ] Ensure robust error handling to manage mid-utterance switching.
  - [ ] Synchronize streams properly to avoid latency or jitter issues.

### Testing and Optimization
- [ ] **Unit and End-to-End Testing**
  - [ ] Write unit tests for each module (mediasoup setup, buffering, recommendation, and rerouting).
  - [ ] Perform end-to-end tests simulating multiple peers.
- [ ] **Performance Profiling and Optimization**
  - [ ] Profile buffering and dynamic rerouting logic to minimize latency.
  - [ ] Optimize the recommendation system to ensure real-time performance.
- [ ] **Logging and Monitoring**
  - [ ] Implement extensive logging for mediasoup events.
  - [ ] Monitor memory usage, transport states, and media routing events.

### Deployment Preparations
- [ ] **Deployment and Scalability**
  - [ ] Prepare deployment scripts or container definitions (e.g., Docker) for scaling the server.
  - [ ] Set up overall system logging and performance monitoring.
- [ ] **Security Configurations**
  - [ ] Ensure the signaling channel and all endpoints are served over HTTPS/WSS.

QUESTION: Can I integrate this later, skipping it for now? Or will it be more complicated?
### User Authentication / Authorization (Firebase Auth Integration)
- [ ] **Integrate Firebase Auth for User Authentication**
  - [ ] Implement client-side Firebase login to obtain the Firebase ID token.
- [ ] **Set Up Firebase Admin SDK on the Backend**
  - [ ] Install Firebase Admin: `npm install firebase-admin`
  - [ ] Initialize Firebase Admin with your service account credentials.
- [ ] **Implement Firebase Authentication Middleware**
  - [ ] Develop middleware to verify Firebase ID tokens from the `Authorization` header.
  - [ ] Map authenticated user data (and any custom claims) to mediasoup operations (e.g., tagging producers/consumers with user IDs).
- [ ] **Secure the Signaling Channel**
  - [ ] Enforce HTTPS/WSS throughout the signaling process.
- [ ] **Role-Based Access Control**
  - [ ] Use Firebase custom claims to manage and enforce roles (e.g., distinguishing between producers and consumers).

## Warnings
- [ ] High memory usage can occur if in-memory buffer management is not tightly controlled; implement strict limits and a robust eviction policy.
- [ ] Dynamic rerouting of streams introduces synchronization challenges that could lead to latency issues.
- [ ] The real-time recommendation system might add significant computational overhead—ensure its performance is optimized.
- [ ] Always secure tokens and sensitive data by enforcing HTTPS/WSS in all client-server communications.
- [ ] Keep Firebase service account credentials secure and restrict access appropriately.

---

This comprehensive checklist provides a step-by-step guide for setting up the mediasoup server with advanced features such as buffering, dynamic rerouting, and integrated Firebase authentication. 