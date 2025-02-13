const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

class BufferManager {
  constructor() {
    this.recordingProcesses = new Map(); // clientId -> {audio: process, video: process}
    this.playbackProcesses = new Map(); // clientId -> {audio: process, video: process}
    this.recordingsPath = path.join(__dirname, '..', 'recordings');
    this.history = [];
    this.portCounter = 10000; // Starting port number for UDP
    
    // Ensure recordings directory exists
    if (!fs.existsSync(this.recordingsPath)) {
      fs.mkdirSync(this.recordingsPath, { recursive: true });
    }
  }

  _getNextPorts() {
    const audioPorts = {
      rtp: this.portCounter++,
      rtcp: this.portCounter++
    };
    const videoPorts = {
      rtp: this.portCounter++,
      rtcp: this.portCounter++
    };
    return { audioPorts, videoPorts };
  }

  getRecordingPath(clientId) {
    const timestamp = Date.now();
    const dir = path.join(this.recordingsPath, `${clientId}_${timestamp}`);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    return { dir, timestamp };
  }

  createBuffer(clientId) {
    const { dir, timestamp } = this.getRecordingPath(clientId);
    const { audioPorts, videoPorts } = this._getNextPorts();
    
    try {
      console.log(`[Buffer] Starting recording for client ${clientId} in directory ${dir}`);
      
      // Start audio recording pipeline with fixed ports
      const audioProcess = spawn('gst-launch-1.0', [
        'udpsrc',
        `port=${audioPorts.rtp}`,
        'caps="application/x-rtp,media=audio,clock-rate=48000,encoding-name=OPUS,payload=111"',
        '!',
        'rtpjitterbuffer',
        'latency=1000',
        'do-lost=true',
        'do-retransmission=true',
        `rtcp-sender-port=${audioPorts.rtcp}`,
        `rtcp-receiver-port=${audioPorts.rtcp}`,
        '!',
        'rtpopusdepay',
        '!',
        'opusparse',
        '!',
        'oggmux',
        '!',
        'filesink',
        'sync=false',
        'async=false',
        `location=${path.join(dir, 'audio.ogg')}`
      ]);

      // Start video recording pipeline with fixed ports
      const videoProcess = spawn('gst-launch-1.0', [
        'udpsrc',
        `port=${videoPorts.rtp}`,
        'caps="application/x-rtp,media=video,clock-rate=90000,encoding-name=VP8,payload=96"',
        '!',
        'rtpjitterbuffer',
        'latency=1000',
        'do-lost=true',
        'do-retransmission=true',
        `rtcp-sender-port=${videoPorts.rtcp}`,
        `rtcp-receiver-port=${videoPorts.rtcp}`,
        '!',
        'rtpvp8depay',
        '!',
        'webmmux',
        '!',
        'filesink',
        'sync=false',
        'async=false',
        `location=${path.join(dir, 'video.webm')}`
      ]);

      // Set up error handlers and logging
      audioProcess.stderr.on('data', (data) => {
        console.log(`[GStreamer Audio] ${data.toString().trim()}`);
      });

      audioProcess.stdout.on('data', (data) => {
        console.log(`[GStreamer Audio] ${data.toString().trim()}`);
      });

      videoProcess.stderr.on('data', (data) => {
        console.log(`[GStreamer Video] ${data.toString().trim()}`);
      });

      videoProcess.stdout.on('data', (data) => {
        console.log(`[GStreamer Video] ${data.toString().trim()}`);
      });

      audioProcess.on('error', (err) => {
        console.error('[GStreamer Audio] Process error:', err);
      });

      videoProcess.on('error', (err) => {
        console.error('[GStreamer Video] Process error:', err);
      });

      audioProcess.on('exit', (code, signal) => {
        console.log(`[GStreamer Audio] Process exited with code ${code} and signal ${signal}`);
      });

      videoProcess.on('exit', (code, signal) => {
        console.log(`[GStreamer Video] Process exited with code ${code} and signal ${signal}`);
      });

      // Store the processes and ports
      this._setupRecordingProcess(clientId, audioProcess, videoProcess, audioPorts.rtp, videoPorts.rtp, timestamp);

      console.log(`[Buffer] Recording started for client ${clientId} with ports:`, {
        audio: audioPorts.rtp,
        video: videoPorts.rtp
      });

      return Promise.resolve({
        audioPipeline: { port: audioPorts.rtp },
        videoPipeline: { port: videoPorts.rtp },
        timestamp
      });
    } catch (error) {
      console.error('[Buffer] Failed to start recording:', error);
      throw error;
    }
  }

  markBufferComplete(clientId) {
    const recording = this.recordingProcesses.get(clientId);
    if (!recording) return false;

    try {
      // Gracefully stop the GStreamer processes
      recording.audio.process.kill('SIGINT');
      recording.video.process.kill('SIGINT');
      
      // Add to history
      this.history.push({
        clientId,
        timestamp: recording.timestamp,
        rtpPacketCount: 0, // Not tracking individual packets anymore
        totalPacketCount: 0,
        bufferSizeKB: 0
      });

      this.recordingProcesses.delete(clientId);
      return true;
    } catch (error) {
      console.error('Error stopping recording:', error);
      return false;
    }
  }

  getBufferedData(clientId, timestamp) {
    const recordingDir = path.join(this.recordingsPath, `${clientId}_${timestamp}`);
    const { audioPorts, videoPorts } = this._getNextPorts();
    
    try {
      console.log(`[Buffer] Starting playback for client ${clientId} from directory ${recordingDir}`);
      
      // Start audio playback pipeline with fixed ports
      const audioProcess = spawn('gst-launch-1.0', [
        'filesrc',
        `location=${path.join(recordingDir, 'audio.ogg')}`,
        '!',
        'oggdemux',
        '!',
        'opusparse',
        '!',
        'rtpopuspay',
        'config-interval=1',
        'pt=96',
        '!',
        'udpsink',
        `port=${audioPorts.rtp}`,
        'host=127.0.0.1',
        'sync=false'
      ]);

      // Start video playback pipeline with fixed ports
      const videoProcess = spawn('gst-launch-1.0', [
        'filesrc',
        `location=${path.join(recordingDir, 'video.webm')}`,
        '!',
        'webmmux',
        '!',
        'rtpvp8pay',
        'config-interval=1',
        'pt=97',
        '!',
        'udpsink',
        `port=${videoPorts.rtp}`,
        'host=127.0.0.1',
        'sync=false'
      ]);

      // Set up error handlers and logging
      audioProcess.stderr.on('data', (data) => {
        console.log(`[GStreamer Audio Playback] ${data.toString()}`);
      });

      videoProcess.stderr.on('data', (data) => {
        console.log(`[GStreamer Video Playback] ${data.toString()}`);
      });

      audioProcess.on('error', (err) => {
        console.error('[GStreamer Audio Playback] Process error:', err);
      });

      videoProcess.on('error', (err) => {
        console.error('[GStreamer Video Playback] Process error:', err);
      });

      // Store the processes
      this._setupPlaybackProcess(clientId, audioProcess, videoProcess, audioPorts.rtp, videoPorts.rtp);

      console.log(`[Buffer] Playback started for client ${clientId} with ports:`, {
        audio: audioPorts.rtp,
        video: videoPorts.rtp
      });

      return Promise.resolve({
        audioPipeline: { port: audioPorts.rtp },
        videoPipeline: { port: videoPorts.rtp }
      });
    } catch (error) {
      console.error('[Buffer] Failed to start playback:', error);
      throw error;
    }
  }

  clearBuffer(clientId) {
    // Stop any active recording
    this.markBufferComplete(clientId);

    // Stop any active playback
    const playback = this.playbackProcesses.get(clientId);
    if (playback) {
      playback.audio.process.kill('SIGINT');
      playback.video.process.kill('SIGINT');
      this.playbackProcesses.delete(clientId);
    }
  }

  getRecordingHistory() {
    return this.history;
  }

  _setupRecordingProcess(clientId, audioProcess, videoProcess, audioPort, videoPort, timestamp) {
    this.recordingProcesses.set(clientId, {
      audio: {
        process: audioProcess,
        port: audioPort
      },
      video: {
        process: videoProcess,
        port: videoPort
      },
      timestamp
    });

    audioProcess.on('error', (err) => console.error('Audio recording error:', err));
    videoProcess.on('error', (err) => console.error('Video recording error:', err));
  }

  _setupPlaybackProcess(clientId, audioProcess, videoProcess, audioPort, videoPort) {
    this.playbackProcesses.set(clientId, {
      audio: {
        process: audioProcess,
        port: audioPort
      },
      video: {
        process: videoProcess,
        port: videoPort
      }
    });

    audioProcess.on('error', (err) => console.error('Audio playback error:', err));
    videoProcess.on('error', (err) => console.error('Video playback error:', err));
  }

  _extractPortFromOutput(output) {
    // GStreamer outputs something like "udpsrc0: actual-buffer-time = 0, actual-latency = 0, port = 12345"
    const match = output.match(/port\s*=\s*(\d+)/);
    return match ? parseInt(match[1], 10) : null;
  }

  close() {
    // Stop all active recordings
    for (const clientId of this.recordingProcesses.keys()) {
      this.markBufferComplete(clientId);
    }

    // Stop all active playbacks
    for (const clientId of this.playbackProcesses.keys()) {
      this.clearBuffer(clientId);
    }
  }
}

module.exports = BufferManager; 