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
      producer: null,
      consumer: null
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

        client.producer = producer;

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

        // Set up RTP recording
        producer.on('rtp', (packet) => {
          console.log(`[RTP] Received RTP packet from producer ${producer.id}, size: ${packet.byteLength} bytes`);
          if (this.bufferManager) {
            this.bufferManager.appendRtpData(clientId, packet);
          }
        });

        producer.on('rtcp', (packet) => {
          if (this.bufferManager) {
            this.bufferManager.appendPacket(clientId, packet);
          }
        });

        ws.send(JSON.stringify({
          type: 'produced',
          data: { id: producer.id }
        }));
        break;

      case 'startRecording':
        console.log(`[Recording] Received startRecording for client ${clientId}`);
        this.bufferManager.createBuffer(clientId);
        ws.send(JSON.stringify({ type: 'recordingStarted', clientId }));
        break;

      case 'stopRecording':
        this.bufferManager.markBufferComplete(clientId);
        ws.send(JSON.stringify({ type: 'recordingStopped', clientId }));
        break;

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
      if (client.producer) client.producer.close();
      if (client.producerTransport) client.producerTransport.close();
      this.bufferManager.clearBuffer(clientId);
      this.clients.delete(clientId);
    }
  }
}

module.exports = WebSocketHandler; 