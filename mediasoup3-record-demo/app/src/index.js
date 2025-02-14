const mediasoup = require('mediasoup-client');
const Peer = require('./peer');

let peer;

// Create video and audio elements
const videoElem = document.createElement('video');
videoElem.id = 'mainVideo';
videoElem.autoplay = true;
videoElem.playsInline = true;
document.body.appendChild(videoElem);

const audioElem = document.createElement('audio');
audioElem.id = 'mainAudio';
audioElem.autoplay = true;
document.body.appendChild(audioElem);

// Connect to server
const socket = new WebSocket(`ws://${window.location.hostname}:3000`);

socket.onopen = () => {
  console.log('Connected to server');
};

socket.onmessage = async (message) => {
  try {
    const jsonMessage = JSON.parse(message.data);
    console.log('Received message:', jsonMessage);
    await handleMessage(jsonMessage);
  } catch (error) {
    console.error('Failed to handle message:', error);
  }
};

socket.onerror = (error) => {
  console.error('WebSocket error:', error);
};

socket.onclose = () => {
  console.log('Disconnected from server');
};

const handleMessage = async (message) => {
  switch (message.action) {
    case 'init':
      await handleInit(message);
      break;
    case 'connect-transport':
      handleConnectTransport(message);
      break;
    default:
      console.log('unknown action %s', message.action);
  }
};

const handleInit = async (message) => {
  // Initialize peer with session ID from server
  peer = new Peer(message.sessionId);

  // Create mediasoup device with hardcoded VP9/Opus capabilities
  const routerRtpCapabilities = {
    codecs: [
      {
        kind: 'video',
        mimeType: 'video/VP9',
        clockRate: 90000,
        preferredPayloadType: 96,
        rtcpFeedback: [
          { type: 'nack' },
          { type: 'nack', parameter: 'pli' },
          { type: 'ccm', parameter: 'fir' },
          { type: 'goog-remb' },
          { type: 'transport-cc' }
        ],
        parameters: {
          'x-google-start-bitrate': 1000,
          'x-google-max-bitrate': 4000000,
          'x-google-min-bitrate': 100000
        }
      },
      {
        kind: 'audio',
        mimeType: 'audio/opus',
        preferredPayloadType: 100,
        clockRate: 48000,
        channels: 2,
        rtcpFeedback: [
          { type: 'nack' },
          { type: 'transport-cc' }
        ],
        parameters: {
          minptime: 10,
          useinbandfec: 1,
          stereo: 1,
          maxplaybackrate: 48000,
          maxaveragebitrate: 128000
        }
      }
    ],
    headerExtensions: [
      {
        kind: 'audio',
        uri: 'urn:ietf:params:rtp-hdrext:sdes:mid',
        preferredId: 1
      },
      {
        kind: 'video',
        uri: 'urn:ietf:params:rtp-hdrext:sdes:mid',
        preferredId: 1
      },
      {
        kind: 'video',
        uri: 'urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id',
        preferredId: 2
      },
      {
        kind: 'audio',
        uri: 'http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time',
        preferredId: 4
      },
      {
        kind: 'video',
        uri: 'http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time',
        preferredId: 4
      },
      {
        kind: 'video',
        uri: 'http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01',
        preferredId: 5
      },
      {
        kind: 'audio',
        uri: 'http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01',
        preferredId: 5
      },
      {
        kind: 'video',
        uri: 'urn:3gpp:video-orientation',
        preferredId: 6
      },
      {
        kind: 'video',
        uri: 'urn:ietf:params:rtp-hdrext:toffset',
        preferredId: 7
      },
      {
        kind: 'video',
        uri: 'http://www.webrtc.org/experiments/rtp-hdrext/abs-capture-time',
        preferredId: 8
      },
      {
        kind: 'audio',
        uri: 'http://www.webrtc.org/experiments/rtp-hdrext/abs-capture-time',
        preferredId: 8
      }
    ]
  };

  const device = new mediasoup.Device();
  await device.load({ routerRtpCapabilities });

  // Create transport
  const transport = device.createRecvTransport(message.transport);

  transport.on('connect', async ({ dtlsParameters }, callback, errback) => {
    socket.send(JSON.stringify({
      action: 'connect-transport',
      sessionId: peer.sessionId,
      transportId: transport.id,
      dtlsParameters
    }));

    peer.connectTransportCallback = callback;
    peer.connectTransportErrback = errback;
  });

  peer.transport = transport;

  // Consume all available producers
  for (const producer of message.producers) {
    if (producer.video) {
      const videoConsumer = await transport.consume({
        id: producer.video.id,
        producerId: producer.video.id,
        kind: 'video',
        rtpParameters: producer.video.rtpParameters
      });

      videoElem.srcObject = new MediaStream([videoConsumer.track]);
    }

    if (producer.audio) {
      const audioConsumer = await transport.consume({
        id: producer.audio.id,
        producerId: producer.audio.id,
        kind: 'audio',
        rtpParameters: producer.audio.rtpParameters
      });

      audioElem.srcObject = new MediaStream([audioConsumer.track]);
    }
  }
};

const handleConnectTransport = (message) => {
  if (peer.connectTransportCallback) {
    peer.connectTransportCallback();
  }
};
