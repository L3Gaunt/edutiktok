const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');

const MediasoupManager = require('./src/MediasoupManager');
const BufferManager = require('./src/BufferManager');
const WebSocketHandler = require('./src/WebSocketHandler');

const app = express();
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Initialize managers
const mediasoupManager = new MediasoupManager();
const bufferManager = new BufferManager();
const wsHandler = new WebSocketHandler(mediasoupManager, bufferManager);

// Handle WebSocket connections
wss.on('connection', (ws) => {
  wsHandler.handleConnection(ws);
});

// Start the server
const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await mediasoupManager.initialize();
    server.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    mediasoupManager.close();
    process.exit(0);
  });
});

start(); 