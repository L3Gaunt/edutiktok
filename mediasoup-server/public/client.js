import 'webrtc-adapter';
import { Device } from 'mediasoup-client';

let device;
let producerTransport;
let videoProducer;
let audioProducer;
let isRecording = false;
let currentClientId = null;
let mediaStream = null;

// Wait for DOM to be loaded before accessing elements
document.addEventListener('DOMContentLoaded', () => {
    const ws = new WebSocket('ws://' + window.location.hostname + ':3000');
    const localVideo = document.getElementById('localVideo');
    const remoteVideo = document.getElementById('remoteVideo');
    const recordButton = document.getElementById('recordButton');
    const statusDiv = document.getElementById('status');

    // Initialize UI
    recordButton.addEventListener('click', toggleRecording);
    recordButton.disabled = true; // Disable until streaming is ready

    // Make local video smaller and position it
    localVideo.style.position = 'fixed';
    localVideo.style.bottom = '20px';
    localVideo.style.right = '20px';
    localVideo.style.width = '200px';
    localVideo.style.zIndex = '1000';

    // Make remote video full screen
    remoteVideo.style.width = '100%';
    remoteVideo.style.height = '100vh';
    remoteVideo.style.objectFit = 'cover';

    ws.onopen = async () => {
        updateStatus('Connected to server');
        // Initialize camera immediately
        try {
            mediaStream = await navigator.mediaDevices.getUserMedia({
                video: true,
                audio: true
            });
            localVideo.srcObject = mediaStream;
            updateStatus('Camera ready');
            
            // Initialize device and transport right away
            ws.send(JSON.stringify({ type: 'getRouterRtpCapabilities' }));
        } catch (error) {
            console.error('Failed to get user media:', error);
            updateStatus('Failed to access camera');
        }
    };

    ws.onclose = () => {
        updateStatus('Disconnected from server');
        stopMediaTracks();
    };

    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        updateStatus('WebSocket error');
        stopMediaTracks();
    };

    ws.onmessage = async ({ data }) => {
        const message = JSON.parse(data);
        console.log('Received message:', message.type);

        switch (message.type) {
            case 'routerRtpCapabilities':
                await loadDevice(message.data);
                break;
            
            case 'producerTransportCreated':
                await connectProducerTransport(message.data);
                break;

            case 'producerTransportConnected':
                updateStatus('Transport connected');
                // Don't automatically start streaming here anymore
                break;

            case 'produced':
                handleProduced(message.data);
                break;

            case 'recordingStarted':
                isRecording = true;
                updateStatus('Recording started');
                recordButton.textContent = 'Stop Recording';
                recordButton.classList.add('recording');
                break;

            case 'recordingStopped':
                isRecording = false;
                updateStatus('Recording stopped');
                recordButton.textContent = 'Start Recording';
                recordButton.classList.remove('recording');
                break;

            case 'recordingData':
                await handleRecordingData(message.data);
                break;

            case 'error':
                console.error('Server error:', message.data.message);
                updateStatus('Error: ' + message.data.message);
                break;

            case 'producerPaused':
                updateStatus(`${message.data.kind} stream paused`);
                break;

            case 'producerResumed':
                updateStatus(`${message.data.kind} stream resumed`);
                break;
        }
    };

    async function loadDevice(routerRtpCapabilities) {
        try {
            device = new Device();
            await device.load({ routerRtpCapabilities });
            updateStatus('Device loaded');
            // Create transport right after device is loaded
            await createProducerTransport();
        } catch (error) {
            console.error('Failed to load device:', error);
            updateStatus('Failed to load device');
        }
    }

    async function createProducerTransport() {
        updateStatus('Creating producer transport...');
        ws.send(JSON.stringify({ type: 'createProducerTransport' }));
    }

    async function connectProducerTransport(transportData) {
        try {
            updateStatus('Setting up transport...');
            producerTransport = device.createSendTransport(transportData);

            producerTransport.on('connect', async ({ dtlsParameters }, callback, errback) => {
                try {
                    updateStatus('Connecting transport...');
                    ws.send(JSON.stringify({
                        type: 'connectProducerTransport',
                        dtlsParameters
                    }));
                    callback();
                } catch (error) {
                    errback(error);
                }
            });

            producerTransport.on('produce', async ({ kind, rtpParameters }, callback, errback) => {
                try {
                    updateStatus('Starting production...');
                    ws.send(JSON.stringify({
                        type: 'produce',
                        kind,
                        rtpParameters
                    }));
                    // Wait for the 'produced' message from server before calling callback
                    const handleProduced = ({ data }) => {
                        const message = JSON.parse(data);
                        if (message.type === 'produced') {
                            callback({ id: message.data.id });
                            ws.removeEventListener('message', handleProduced);
                        }
                    };
                    ws.addEventListener('message', handleProduced);
                } catch (error) {
                    errback(error);
                }
            });

            // Create producers right after transport is ready
            try {
                await startStreaming();
            } catch (error) {
                console.error('Failed to create initial producers:', error);
                updateStatus('Failed to create producers');
            }

            // Enable record button once everything is ready
            recordButton.disabled = false;
            updateStatus('Ready to record');
        } catch (error) {
            console.error('Failed to create producer transport:', error);
            updateStatus('Failed to create producer transport');
        }
    }

    async function toggleRecording() {
        if (!isRecording) {
            try {
                updateStatus('Starting recording...');
                ws.send(JSON.stringify({
                    type: 'startRecording'
                }));
                // isRecording will be set to true when server confirms with 'recordingStarted' message
                updateStatus('Recording requested');
            } catch (error) {
                console.error('Error starting recording:', error);
                updateStatus('Failed to start recording');
            }
        } else {
            try {
                updateStatus('Stopping recording...');
                ws.send(JSON.stringify({
                    type: 'stopRecording'
                }));
                // isRecording will be set to false when server confirms with 'recordingStopped' message
                updateStatus('Stop recording requested');
            } catch (error) {
                console.error('Error stopping recording:', error);
                updateStatus('Failed to stop recording');
            }
        }
    }

    function handleProduced(data) {
        // Store the producer in the appropriate variable based on kind
        if (data.kind === 'video') {
            videoProducer.id = data.id;
            updateStatus('Video producer created');
        } else if (data.kind === 'audio') {
            audioProducer.id = data.id;
            updateStatus('Audio producer created');
        }
        
        // Check if both producers are ready
        if (videoProducer?.id && audioProducer?.id) {
            updateStatus('Both producers ready');
            recordButton.disabled = false;
        }
    }

    async function handleRecordingData(data) {
        const { rtpData, controlPackets } = data;
        
        // Handle RTP packets for media playback
        if (rtpData && rtpData.length > 0) {
            // Use MediaSource API or WebRTC to play back the RTP data
            // This is a simplified example - actual implementation would need proper RTP handling
            const mediaSource = new MediaSource();
            remoteVideo.src = URL.createObjectURL(mediaSource);
            
            mediaSource.addEventListener('sourceopen', () => {
                const sourceBuffer = mediaSource.addSourceBuffer('video/webm; codecs="vp8,opus"');
                sourceBuffer.addEventListener('updateend', () => {
                    if (!sourceBuffer.updating && rtpData.length > 0) {
                        // Convert RTP packets to media segments and append
                        // This is where you'd need proper RTP to media segment conversion
                        sourceBuffer.appendBuffer(rtpData);
                    }
                });
            });
        }
    }

    function updateStatus(message) {
        statusDiv.textContent = 'Status: ' + message;
        console.log('Status:', message);
    }

    function stopMediaTracks() {
        // Only stop tracks when actually cleaning up (e.g., page unload or explicit stop)
        if (mediaStream) {
            mediaStream.getTracks().forEach(track => {
                track.stop();
            });
            mediaStream = null;
        }
        if (localVideo.srcObject) {
            localVideo.srcObject = null;
        }
        if (videoProducer) {
            try {
                videoProducer.close();
            } catch (error) {
                console.error('Error closing video producer:', error);
            }
            videoProducer = null;
        }
        if (audioProducer) {
            try {
                audioProducer.close();
            } catch (error) {
                console.error('Error closing audio producer:', error);
            }
            audioProducer = null;
        }
    }

    async function startStreaming() {
        if (!mediaStream || !mediaStream.active) {
            try {
                mediaStream = await navigator.mediaDevices.getUserMedia({
                    video: true,
                    audio: true
                });
                localVideo.srcObject = mediaStream;
            } catch (error) {
                console.error('Failed to get user media:', error);
                updateStatus('Failed to access camera');
                return;
            }
        }

        const videoTrack = mediaStream.getVideoTracks()[0];
        const audioTrack = mediaStream.getAudioTracks()[0];
        
        if (!videoTrack || !audioTrack || !videoTrack.enabled || !audioTrack.enabled) {
            throw new Error('Media tracks are not available');
        }
        
        updateStatus('Creating producers in parallel...');
        
        try {
            // Create both producers in parallel
            [videoProducer, audioProducer] = await Promise.all([
                producerTransport.produce({ 
                    track: videoTrack,
                    kind: 'video',
                    paused: true
                }),
                producerTransport.produce({ 
                    track: audioTrack,
                    kind: 'audio',
                    paused: true
                })
            ]);
            
            updateStatus('Producers created and paused');
        } catch (error) {
            console.error('Failed to create producers:', error);
            updateStatus('Failed to create producers');
            throw error;
        }
    }
}); 