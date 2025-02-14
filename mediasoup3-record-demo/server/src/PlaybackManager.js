const GStreamer = require('./gstreamer');
const { createTransport } = require('./mediasoup');
const { getPort, releasePort } = require('./port');

class PlaybackManager {
  constructor(router) {
    this.router = router;
    this.producers = new Map(); // filename -> {video, audio} producers
    this.transports = new Map(); // filename -> transport
    this.gstreamerProcesses = new Map(); // filename -> GStreamer process
  }

  async startPlayback(filename) {
    // If already playing, stop first
    if (this.producers.has(filename)) {
      await this.stopPlayback(filename);
    }

    // Create RTP transport for GStreamer
    const rtpTransport = await createTransport('plain', this.router, {
      listenIp: { ip: '0.0.0.0', announcedIp: '127.0.0.1' },
      rtcpMux: true,
      comedia: true
    });

    // Get ports for video and audio
    const videoRtpPort = await getPort();
    const audioRtpPort = await getPort();

    // Connect transport
    await rtpTransport.connect({
      ip: '127.0.0.1',
      port: videoRtpPort
    });

    // Store transport
    this.transports.set(filename, rtpTransport);

    // Create video producer
    const videoProducer = await rtpTransport.produce({
      kind: 'video',
      rtpParameters: {
        codecs: [
          {
            mimeType: 'video/VP9',
            payloadType: 96,
            clockRate: 90000
          }
        ],
        encodings: [{ ssrc: 1111 }]
      }
    });

    // Create audio producer
    const audioProducer = await rtpTransport.produce({
      kind: 'audio',
      rtpParameters: {
        codecs: [
          {
            mimeType: 'audio/opus',
            payloadType: 100,
            clockRate: 48000,
            channels: 2
          }
        ],
        encodings: [{ ssrc: 2222 }]
      }
    });

    // Store producers
    this.producers.set(filename, { video: videoProducer, audio: audioProducer });

    // Start GStreamer process
    const gstreamer = new GStreamer();
    const pipeline = [
      'videotestsrc pattern=ball ! video/x-raw,width=640,height=480,framerate=30/1',
      '!',
      'videoconvert',
      '!',
      'vp9enc deadline=1',
      '!',
      'rtpvp9pay pt=96 ssrc=1111',
      '!',
      `udpsink host=127.0.0.1 port=${videoRtpPort} sync=false async=false`,
      'audiotestsrc wave=sine',
      '!',
      'audioconvert',
      '!',
      'audioresample',
      '!',
      'opusenc',
      '!',
      'rtpopuspay pt=100 ssrc=2222',
      '!',
      `udpsink host=127.0.0.1 port=${audioRtpPort} sync=false async=false`
    ].join(' ');

    await gstreamer.launch(pipeline);
    this.gstreamerProcesses.set(filename, gstreamer);
  }

  async stopPlayback(filename) {
    // Stop GStreamer process
    const gstreamer = this.gstreamerProcesses.get(filename);
    if (gstreamer) {
      await gstreamer.kill();
      this.gstreamerProcesses.delete(filename);
    }

    // Close producers
    const producers = this.producers.get(filename);
    if (producers) {
      await producers.video.close();
      await producers.audio.close();
      this.producers.delete(filename);
    }

    // Close transport
    const transport = this.transports.get(filename);
    if (transport) {
      await transport.close();
      this.transports.delete(filename);
    }
  }
}

module.exports = PlaybackManager; 