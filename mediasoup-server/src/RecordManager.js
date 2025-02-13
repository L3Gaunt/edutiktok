const { spawn } = require('child_process');
const os = require('os');

class RecordManager {
  constructor() {
    this.recordingProcesses = new Map();
    this.plainRtpTransportConfig = {
      listenIp: '127.0.0.1',
      rtcpMux: true,
      comedia: false
    };
  }

  async getPort() {
    const min = 10000;
    const max = 59999;
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  async startRecording(peer, producer, router) {
    if (this.recordingProcesses.has(producer.id)) {
      throw new Error('Recording already in progress for this producer');
    }

    const rtpPort = await this.getPort();
    const gstProcess = await this.createGStreamerProcess(producer.kind, rtpPort, producer.id);

    // Wait a bit for GStreamer to start and bind to its port
    await new Promise(resolve => setTimeout(resolve, 1000));

    const rtpTransport = await router.createPlainTransport(this.plainRtpTransportConfig);

    await rtpTransport.connect({
      ip: '127.0.0.1',
      port: rtpPort
    });

    const codecs = [];
    const routerCodec = router.rtpCapabilities.codecs.find(
      codec => codec.kind === producer.kind
    );
    codecs.push(routerCodec);

    const rtpCapabilities = {
      codecs,
      rtcpFeedback: []
    };

    const consumer = await rtpTransport.consume({
      producerId: producer.id,
      rtpCapabilities,
      paused: true
    });

    this.recordingProcesses.set(producer.id, {
      rtpTransport,
      consumer,
      process: gstProcess,
      rtpPort
    });

    await consumer.resume();

    return {
      rtpTransport,
      consumer,
      process: gstProcess
    };
  }

  async createGStreamerProcess(kind, rtpPort, producerId) {
    const outputPath = `./recordings/${producerId}_${Date.now()}.mp4`;
    let gstCommand;

    if (kind === 'audio') {
      gstCommand = [
        'gst-launch-1.0',
        '-v',
        'udpsrc',
        `port=${rtpPort}`,
        'do-timestamp=true',
        'buffer-size=524288',
        'caps=application/x-rtp,media=audio,clock-rate=48000,encoding-name=OPUS,payload=100',
        '!',
        'rtpjitterbuffer',
        'latency=1000',
        'do-lost=true',
        '!',
        'rtpopusdepay',
        '!',
        'opusdec',
        '!',
        'audioconvert',
        '!',
        'audioresample',
        '!',
        'avenc_aac',
        'bitrate=128000',
        '!',
        'queue',
        'max-size-buffers=0',
        'max-size-time=0',
        'max-size-bytes=0',
        '!',
        'mp4mux',
        'faststart=true',
        'fragment-duration=10',
        '!',
        'filesink',
        `location=${outputPath}`,
        'sync=false',
        'async=false'
      ];
    } else {
      gstCommand = [
        'gst-launch-1.0',
        '-v',
        'udpsrc',
        `port=${rtpPort}`,
        'do-timestamp=true',
        'buffer-size=524288',
        'caps=application/x-rtp,media=video,clock-rate=90000,encoding-name=VP8,payload=101',
        '!',
        'rtpjitterbuffer',
        'latency=1000',
        'do-lost=true',
        '!',
        'rtpvp8depay',
        '!',
        'vp8dec',
        '!',
        'videoconvert',
        '!',
        'x264enc',
        'tune=zerolatency',
        'speed-preset=superfast',
        'bitrate=2000',
        'key-int-max=60',
        '!',
        'queue',
        'max-size-buffers=0',
        'max-size-time=0',
        'max-size-bytes=0',
        '!',
        'h264parse',
        'config-interval=-1',
        '!',
        'mp4mux',
        'faststart=true',
        'fragment-duration=10',
        '!',
        'filesink',
        `location=${outputPath}`,
        'sync=false',
        'async=false'
      ];
    }

    console.log('Starting GStreamer with command:', gstCommand.join(' '));

    const process = spawn(gstCommand[0], gstCommand.slice(1), {
      detached: false,
      stdio: 'pipe'
    });

    process.stdout.on('data', (data) => {
      console.log(`GStreamer stdout: ${data}`);
    });

    process.stderr.on('data', (data) => {
      console.error(`GStreamer stderr: ${data}`);
    });

    process.on('close', (code) => {
      console.log(`GStreamer process exited with code ${code}`);
    });

    // Return a promise that resolves when GStreamer is ready or fails
    return new Promise((resolve, reject) => {
      let initialized = false;
      let errorOutput = '';
      
      const timeout = setTimeout(() => {
        if (!initialized) {
          console.error('GStreamer initialization timeout. Error output:', errorOutput);
          process.kill();
          reject(new Error('GStreamer initialization timeout'));
        }
      }, 5000);

      process.stderr.on('data', (data) => {
        const output = data.toString();
        errorOutput += output;
        
        // Check for various success indicators
        if (output.includes('Pipeline is PLAYING') || 
            output.includes('Pipeline is live and does not need PREROLL') ||
            output.includes('/GstPipeline:pipeline0/GstUDPSrc:udpsrc0.GstPad:src')) {
          clearTimeout(timeout);
          initialized = true;
          resolve(process);
        }
        
        // Check for fatal errors
        if (output.includes('ERROR:') && !output.includes('Resource not found')) {
          clearTimeout(timeout);
          process.kill();
          reject(new Error(`GStreamer error: ${output}`));
        }
      });

      process.on('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });

      process.on('exit', (code) => {
        if (!initialized) {
          clearTimeout(timeout);
          reject(new Error(`GStreamer exited with code ${code}. Error output: ${errorOutput}`));
        }
      });
    });
  }

  async stopRecording(producerId) {
    const recordingInfo = this.recordingProcesses.get(producerId);
    if (!recordingInfo) {
      throw new Error('No recording found for this producer');
    }

    const { rtpTransport, consumer, process } = recordingInfo;

    if (consumer) {
      consumer.close();
    }
    if (rtpTransport) {
      rtpTransport.close();
    }
    if (process) {
      // Send EOS (End of Stream) signal before killing
      process.stdin.write('q');
      setTimeout(() => process.kill('SIGINT'), 500);
    }

    this.recordingProcesses.delete(producerId);
  }
}

module.exports = RecordManager;