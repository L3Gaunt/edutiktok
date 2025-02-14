// Config file for mediasoup elements

const os = require('os');

module.exports = Object.freeze({
  numWorkers: Object.keys(os.cpus()).length,
  worker: {
    logLevel: 'debug',
    logTags: [
      'rtp',
      'srtp',
      'rtcp',
    ],
    rtcMinPort: 40000,
    rtcMaxPort: 49999
  },
  router: {
    mediaCodecs: [
      {
        kind: 'audio',
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2
      },
      {
        kind: 'video',
        mimeType: 'video/VP9',
        clockRate: 90000,
        parameters: {
          'profile-id': 0,
          'x-google-start-bitrate': 1000,
          'x-google-max-bitrate': 4000000,
          'x-google-min-bitrate': 100000
        },
        rtcpFeedback: [
          { type: 'nack' },
          { type: 'nack', parameter: 'pli' },
          { type: 'ccm', parameter: 'fir' },
          { type: 'goog-remb' },
          { type: 'transport-cc' }
        ]
      }
    ]
  },
  webRtcTransport: {
    listenIps: [ { ip: '0.0.0.0', announcedIp: '127.0.0.1' } ], // TODO: Change announcedIp to your external IP or domain name
    enableUdp: true,
    enableTcp: true,
    preferUdp: true,
    maxIncomingBitrate: 1500000
  },
  plainRtpTransport: {
    listenIp: { ip: '0.0.0.0', announcedIp: '127.0.0.1' }, // TODO: Change announcedIp to your external IP or domain name
    rtcpMux: true,
    comedia: false
  }
});
