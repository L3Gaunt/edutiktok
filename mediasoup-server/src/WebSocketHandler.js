class WebSocketHandler {
  constructor(mediasoupManager, bufferManager) {
    this.mediasoupManager = mediasoupManager;
    this.bufferManager = bufferManager;
    this.clients = new Map();
  }

  handleConnection(ws) {
    console.log('New WebSocket connection');
    const clientId = Date.now().toString();
    
    this.clients.set(clientId, {
      ws,
      producerTransport: null,
      consumerTransport: null,
      producers: new Map(),
      consumers: new Map(),
      recordingTransports: null
    });

    ws.on('message', async (message) => {
      try {
        await this.handleMessage(clientId, message);
      } catch (error) {
        console.error('Error handling message:', error);
        ws.send(JSON.stringify({
          type: 'error',
          data: { message: error.message }
        }));
      }
    });

    ws.on('close', () => this.handleDisconnection(clientId));
  }

  async handleMessage(clientId, message) {
    const data = JSON.parse(message);
    const client = this.clients.get(clientId);
    
    if (!client) {
      throw new Error('Client not found');
    }

    const { ws } = client;
    console.log(`Data ${data.type} `);

    switch (data.type) {
      case 'getRouterRtpCapabilities':
        ws.send(JSON.stringify({
          type: 'routerRtpCapabilities',
          data: this.mediasoupManager.getRtpCapabilities()
        }));
        break;

      case 'createProducerTransport':
        const { transport, params } = await this.mediasoupManager.createWebRtcTransport();
        client.producerTransport = transport;
        ws.send(JSON.stringify({
          type: 'producerTransportCreated',
          data: params
        }));
        break;

      case 'connectProducerTransport':
        await this.mediasoupManager.connectTransport(
          client.producerTransport,
          data.dtlsParameters
        );
        ws.send(JSON.stringify({ type: 'producerTransportConnected' }));
        break;

      case 'produce':
        const producer = await this.mediasoupManager.createProducer(
          client.producerTransport,
          data.kind,
          data.rtpParameters
        );

        client.producers.set(data.kind, producer);

        // Handle native mediasoup pause/resume events
        producer.on('pause', () => {
          console.log(`Producer ${producer.id} paused`);
          ws.send(JSON.stringify({
            type: 'producerPaused',
            data: { kind: producer.kind }
          }));
        });

        producer.on('resume', () => {
          console.log(`Producer ${producer.id} resumed`);
          ws.send(JSON.stringify({
            type: 'producerResumed',
            data: { kind: producer.kind }
          }));
        });

        ws.send(JSON.stringify({
          type: 'produced',
          data: { id: producer.id }
        }));
        break;

      case 'startRecording': {
        console.log(`[Recording] Received startRecording for client ${clientId}`);
        const audioProducer = client.producers.get('audio');
        const videoProducer = client.producers.get('video');
        
        if (!audioProducer || !videoProducer) {
          throw new Error('Both audio and video producers must exist to start recording');
        }

        // Create GStreamer pipelines and get UDP ports
        const { audioPipeline, videoPipeline, timestamp } = await this.bufferManager.createBuffer(clientId);

        const router = this.mediasoupManager.getRouter();

        console.log(`[Recording] Creating plain transports for GStreamer. Audio port: ${audioPipeline.port}, Video port: ${videoPipeline.port}`);

        // Create plain RTP transports for GStreamer
        const audioRtpTransport = await router.createPlainTransport({
          listenIp: { ip: '127.0.0.1', announcedIp: null },
          rtcpMux: false,
          comedia: false,
          enableSctp: false,
          enableSrtp: false
        });

        const videoRtpTransport = await router.createPlainTransport({
          listenIp: { ip: '127.0.0.1', announcedIp: null },
          rtcpMux: false,
          comedia: false,
          enableSctp: false,
          enableSrtp: false
        });

        console.log('[Recording] Plain transports created, connecting to GStreamer ports');

        // Connect transports to GStreamer UDP ports
        await audioRtpTransport.connect({
          ip: '127.0.0.1',
          port: audioPipeline.port,
          rtcpPort: audioPipeline.port + 1
        });

        await videoRtpTransport.connect({
          ip: '127.0.0.1',
          port: videoPipeline.port,
          rtcpPort: videoPipeline.port + 1
        });

        console.log('[Recording] Creating consumers for GStreamer recording');

        // Create consumers to forward RTP to GStreamer
        const audioConsumer = await audioRtpTransport.consume({
          producerId: audioProducer.id,
          rtpCapabilities: router.rtpCapabilities,
          paused: false,
          enableRtx: false
        });

        const videoConsumer = await videoRtpTransport.consume({
          producerId: videoProducer.id,
          rtpCapabilities: router.rtpCapabilities,
          paused: false,
          enableRtx: false
        });

        // Enable RTP forwarding
        await audioConsumer.resume();
        await videoConsumer.resume();

        console.log(`[Recording] Consumers created and resumed. Audio consumer ID: ${audioConsumer.id}, Video consumer ID: ${videoConsumer.id}`);

        // Verify producer state immediately
        console.log('[Recording] Producer State:', {
          audio: {
            id: audioProducer.id,
            active: audioProducer.active,
            paused: audioProducer.paused,
            score: audioProducer.score,
            kind: audioProducer.kind
          },
          video: {
            id: videoProducer.id,
            active: videoProducer.active,
            paused: videoProducer.paused,
            score: videoProducer.score,
            kind: videoProducer.kind
          }
        });

        // Verify transport state
        console.log('[Recording] Transport State:', {
          audio: {
            closed: audioRtpTransport.closed,
            connected: audioRtpTransport.connected,
            connectionState: audioRtpTransport.connectionState
          },
          video: {
            closed: videoRtpTransport.closed,
            connected: videoRtpTransport.connected,
            connectionState: videoRtpTransport.connectionState
          }
        });

        // Verify consumer state
        console.log('[Recording] Consumer State:', {
          audio: {
            id: audioConsumer.id,
            paused: audioConsumer.paused,
            producerPaused: audioConsumer.producerPaused,
            score: audioConsumer.score,
            kind: audioConsumer.kind
          },
          video: {
            id: videoConsumer.id,
            paused: videoConsumer.paused,
            producerPaused: videoConsumer.producerPaused,
            score: videoConsumer.score,
            kind: videoConsumer.kind
          }
        });

        // Add RTP flow debugging
        audioConsumer.on('producerresume', () => {
          console.log('[Recording] Audio producer resumed');
        });

        audioConsumer.on('producerpause', () => {
          console.log('[Recording] Audio producer paused');
        });

        videoConsumer.on('producerresume', () => {
          console.log('[Recording] Video producer resumed');
        });

        videoConsumer.on('producerpause', () => {
          console.log('[Recording] Video producer paused');
        });

        // Monitor RTP packets
        let audioPacketCount = 0;
        let videoPacketCount = 0;
        const startTime = Date.now();

        // Monitor direct consumer stats
        audioConsumer.observer.on('close', () => {
          console.log('[Recording] Audio consumer closed');
        });

        videoConsumer.observer.on('close', () => {
          console.log('[Recording] Video consumer closed');
        });

        // Monitor transport connection state
        audioRtpTransport.observer.on('close', () => {
          console.log('[Recording] Audio transport closed');
        });

        videoRtpTransport.observer.on('close', () => {
          console.log('[Recording] Video transport closed');
        });

        // Monitor transport connection state changes
        audioRtpTransport.on('connect', () => {
          console.log('[Recording] Audio transport connected');
        });

        videoRtpTransport.on('connect', () => {
          console.log('[Recording] Video transport connected');
        });

        // Monitor RTP data flow
        audioConsumer.on('transportclose', () => {
          console.log('[Recording] Audio consumer transport closed');
        });

        videoConsumer.on('transportclose', () => {
          console.log('[Recording] Video consumer transport closed');
        });

        // Monitor RTP/RTCP
        audioRtpTransport.on('rtp', (data) => {
          audioPacketCount++;
          console.log(`[Recording] Audio RTP received, packet count: ${audioPacketCount}, size: ${data.length} bytes`);
        });

        videoRtpTransport.on('rtp', (data) => {
          videoPacketCount++;
          console.log(`[Recording] Video RTP received, packet count: ${videoPacketCount}, size: ${data.length} bytes`);
        });

        audioRtpTransport.on('rtcp', (data) => {
          console.log(`[Recording] Audio RTCP received, size: ${data.length} bytes`);
        });

        videoRtpTransport.on('rtcp', (data) => {
          console.log(`[Recording] Video RTCP received, size: ${data.length} bytes`);
        });

        // Log initial producer and consumer states
        console.log('[Recording] Initial states:', JSON.stringify({
          audioProducer: {
            paused: audioProducer.paused,
            closed: audioProducer.closed,
            score: audioProducer.score,
            kind: audioProducer.kind,
            rtpParameters: audioProducer.rtpParameters
          },
          videoProducer: {
            paused: videoProducer.paused,
            closed: videoProducer.closed,
            score: videoProducer.score,
            kind: videoProducer.kind,
            rtpParameters: videoProducer.rtpParameters
          },
          audioConsumer: {
            paused: audioConsumer.paused,
            closed: audioConsumer.closed,
            score: audioConsumer.score,
            kind: audioConsumer.kind,
            rtpParameters: audioConsumer.rtpParameters
          },
          videoConsumer: {
            paused: videoConsumer.paused,
            closed: videoConsumer.closed,
            score: videoConsumer.score,
            kind: videoConsumer.kind,
            rtpParameters: videoConsumer.rtpParameters
          }
        }, null, 2));

        // Resume the producers if they're paused
        if (audioProducer.paused) {
          console.log('[Recording] Resuming audio producer');
          await audioProducer.resume();
        }

        if (videoProducer.paused) {
          console.log('[Recording] Resuming video producer');
          await videoProducer.resume();
        }

        // Log producer and consumer stats more frequently
        const statsInterval = setInterval(async () => {
          try {
            const [audioProducerStats, videoProducerStats, audioConsumerStats, videoConsumerStats] = await Promise.all([
              audioProducer.getStats(),
              videoProducer.getStats(),
              audioConsumer.getStats(),
              videoConsumer.getStats()
            ]);

            console.log('[Recording] Stats:', JSON.stringify({
              timestamp: new Date().toISOString(),
              audio: {
                producer: audioProducerStats,
                consumer: audioConsumerStats,
                producerScore: audioProducer.score,
                consumerScore: audioConsumer.score
              },
              video: {
                producer: videoProducerStats,
                consumer: videoConsumerStats,
                producerScore: videoProducer.score,
                consumerScore: videoConsumer.score
              }
            }, null, 2));
          } catch (error) {
            console.error('[Recording] Error getting stats:', error);
          }
        }, 1000);

        // Store transports and consumers for cleanup
        client.recordingTransports = {
          audio: audioRtpTransport,
          video: videoRtpTransport,
          audioConsumer,
          videoConsumer,
          statsInterval  // Store interval for cleanup
        };

        ws.send(JSON.stringify({ 
          type: 'recordingStarted', 
          clientId,
          timestamp 
        }));
        break;
      }

      case 'stopRecording': {
        console.log('[Recording] Stopping recording, cleaning up resources');
        // Clean up recording transports
        if (client.recordingTransports) {
          // Clear stats interval
          if (client.recordingTransports.statsInterval) {
            clearInterval(client.recordingTransports.statsInterval);
          }

          // Close consumers and transports
          client.recordingTransports.audioConsumer?.close();
          client.recordingTransports.videoConsumer?.close();
          client.recordingTransports.audio?.close();
          client.recordingTransports.video?.close();
          delete client.recordingTransports;
        }

        this.bufferManager.markBufferComplete(clientId);
        ws.send(JSON.stringify({ type: 'recordingStopped', clientId }));
        break;
      }

      case 'consumeRecording':
        const bufferedData = this.bufferManager.getBufferedData(data.clientId, data.offset || 0);
        if (bufferedData) {
          ws.send(JSON.stringify({
            type: 'recordingData',
            data: bufferedData
          }));
        }
        break;

      default:
        console.warn('Unknown message type:', data.type);
    }
  }

  handleDisconnection(clientId) {
    console.log('Client disconnected:', clientId);
    const client = this.clients.get(clientId);
    
    if (client) {
      // Clean up recording transports
      if (client.recordingTransports) {
        client.recordingTransports.audioConsumer?.close();
        client.recordingTransports.videoConsumer?.close();
        client.recordingTransports.audio?.close();
        client.recordingTransports.video?.close();
      }

      for (const producer of client.producers.values()) {
        producer.close();
      }
      if (client.producerTransport) client.producerTransport.close();
      this.bufferManager.clearBuffer(clientId);
      this.clients.delete(clientId);
    }
  }
}

module.exports = WebSocketHandler; 