const mediasoup = require('mediasoup');

class MediasoupManager {
  constructor() {
    this.worker = null;
    this.router = null;
    this.workerSettings = {
      rtcMinPort: 10000,
      rtcMaxPort: 10100,
      logLevel: 'warn',
      logTags: ['info', 'ice', 'dtls', 'rtp', 'srtp', 'rtcp']
    };

    this.webRtcTransportOptions = {
      listenIps: [
        {
          ip: '0.0.0.0',
          announcedIp: '127.0.0.1'
        }
      ],
      enableUdp: true,
      enableTcp: true,
      preferUdp: true,
    };

    this.mediaCodecs = [
      {
        kind: 'video',
        mimeType: 'video/VP8',
        clockRate: 90000,
        parameters: {
          'x-google-start-bitrate': 1000
        }
      },
      {
        kind: 'audio',
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2
      }
    ];
  }

  async initialize() {
    try {
      this.worker = await mediasoup.createWorker(this.workerSettings);
      console.log('Mediasoup worker created');

      this.worker.on('died', () => {
        console.error('Mediasoup worker died, exiting...');
        process.exit(1);
      });

      this.router = await this.worker.createRouter({ mediaCodecs: this.mediaCodecs });
      console.log('Router created');
      
      return true;
    } catch (error) {
      console.error('Failed to initialize MediasoupManager:', error);
      throw error;
    }
  }

  async createWebRtcTransport() {
    try {
      const transport = await this.router.createWebRtcTransport(this.webRtcTransportOptions);
      return {
        transport,
        params: {
          id: transport.id,
          iceParameters: transport.iceParameters,
          iceCandidates: transport.iceCandidates,
          dtlsParameters: transport.dtlsParameters,
        }
      };
    } catch (error) {
      console.error('Failed to create WebRTC transport:', error);
      throw error;
    }
  }

  getRouter() {
    return this.router;
  }

  getRtpCapabilities() {
    return this.router.rtpCapabilities;
  }

  async connectTransport(transport, dtlsParameters) {
    await transport.connect({ dtlsParameters });
  }

  async createProducer(transport, kind, rtpParameters) {
    return await transport.produce({ kind, rtpParameters });
  }

  async createConsumer(transport, producer, rtpCapabilities) {
    if (!this.router.canConsume({ producerId: producer.id, rtpCapabilities })) {
      throw new Error('Cannot consume this producer');
    }
    return await transport.consume({ producerId: producer.id, rtpCapabilities });
  }

  close() {
    if (this.worker) {
      this.worker.close();
    }
  }
}

module.exports = MediasoupManager; 