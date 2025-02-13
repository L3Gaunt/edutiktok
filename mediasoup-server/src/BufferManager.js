class BufferManager {
  constructor() {
    this.buffers = new Map();
    this.history = [];
    this.rtpBuffers = new Map(); // Store RTP data
  }

  createBuffer(clientId) {
    this.buffers.set(clientId, []);
    this.rtpBuffers.set(clientId, []);
    console.log(`[Buffer] New recording started for client ${clientId}`);
    return true;
  }

  appendPacket(clientId, packet) {
    const buffer = this.buffers.get(clientId);
    console.log(`[Buffer] Appending packet for client ${clientId}`);
    if (buffer) {
      buffer.push(packet);
      return true;
    }
    return false;
  }

  appendRtpData(clientId, rtpData) {
    const buffer = this.rtpBuffers.get(clientId);
    console.log(`[Buffer] Appending RTP data for client ${clientId}`);
    if (buffer) {
      buffer.push(rtpData);
      return true;
    }
    return false;
  }

  markBufferComplete(clientId) {
    const buffer = this.buffers.get(clientId);
    const rtpBuffer = this.rtpBuffers.get(clientId);
    if (buffer && rtpBuffer) {
      const bufferSizeKB = this._calculateBufferSize(rtpBuffer);
      console.log(`[Buffer] Recording stopped for client ${clientId}. Buffer size: ${bufferSizeKB.toFixed(2)} KB, RTP packets: ${rtpBuffer.length}, Control packets: ${buffer.length}`);
      
      this.history.push({ 
        clientId, 
        timestamp: Date.now(),
        rtpPacketCount: rtpBuffer.length,
        totalPacketCount: buffer.length,
        bufferSizeKB: bufferSizeKB
      });
      return true;
    }
    return false;
  }

  getBufferedData(clientId, offset = 0) {
    const buffer = this.buffers.get(clientId);
    const rtpBuffer = this.rtpBuffers.get(clientId);
    if (buffer && rtpBuffer) {
      console.log(`[Buffer] Accessing recording for client ${clientId} at offset ${offset}. Total available packets: ${rtpBuffer.length - offset}`);
      return {
        controlPackets: buffer.slice(offset),
        rtpData: rtpBuffer.slice(offset)
      };
    }
    return null;
  }

  clearBuffer(clientId) {
    this.buffers.delete(clientId);
    this.rtpBuffers.delete(clientId);
  }

  getRecordingHistory() {
    return this.history;
  }

  _calculateBufferSize(rtpBuffer) {
    return rtpBuffer.reduce((total, packet) => total + (packet.byteLength || 0), 0) / 1024;
  }
}

module.exports = BufferManager; 