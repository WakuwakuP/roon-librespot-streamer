const express = require('express');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.STREAMING_PORT || 3000;
const FIFO_PATH = process.env.FIFO_PATH || '/tmp/librespot-audio';
const STREAM_FORMAT = process.env.STREAM_FORMAT || 'flac';
const BITRATE = process.env.BITRATE || '320k';
const SILENCE_ON_NO_INPUT = process.env.SILENCE_ON_NO_INPUT !== 'false'; // Default to true

// Audio constants
const SAMPLE_RATE = 44100;
const CHANNEL_LAYOUT = 'stereo';
const CHANNELS = 2;
const BYTES_PER_SAMPLE = 2; // 16-bit = 2 bytes
const BYTES_PER_SECOND = SAMPLE_RATE * CHANNELS * BYTES_PER_SAMPLE;

let currentClients = new Set();

// Shared audio state
let isReceivingAudio = false;

// Rate limiting middleware to prevent abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

// Apply rate limiting to all routes
app.use(limiter);

// Helper function to cleanup FFmpeg process
function cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval) {
  // Prevent multiple cleanup attempts
  if (res._cleanedUp) {
    return;
  }
  res._cleanedUp = true;
  
  currentClients.delete(res);
  
  if (silenceInterval) {
    clearInterval(silenceInterval);
  }
  
  if (fifoReadStream) {
    try {
      fifoReadStream.destroy();
    } catch (e) {
      // Ignore
    }
  }
  
  if (ffmpeg && !ffmpeg.killed) {
    try {
      ffmpeg.stdin.end();
      ffmpeg.kill('SIGTERM');
    } catch (error) {
      // Ignore errors if process already exited
      console.log('FFmpeg cleanup: process already terminated');
    }
  }
}

// Generate silence buffer
function generateSilence(durationMs = 100) {
  const numSamples = Math.floor((SAMPLE_RATE * durationMs) / 1000);
  const bufferSize = numSamples * CHANNELS * BYTES_PER_SAMPLE;
  return Buffer.alloc(bufferSize, 0);
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    clients: currentClients.size,
    fifo: fs.existsSync(FIFO_PATH),
    receivingAudio: isReceivingAudio
  });
});

// Stream endpoint
app.get('/stream', (req, res) => {
  console.log('New client connected:', req.ip);
  
  // Set headers for audio streaming
  res.setHeader('Content-Type', `audio/${STREAM_FORMAT}`);
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Accept-Ranges', 'none');
  res.setHeader('icy-name', 'Spotify via librespot');
  res.setHeader('icy-description', 'Streaming from Spotify Connect');
  
  // Track this client
  currentClients.add(res);
  
  // Build FFmpeg command - always read from stdin (pipe)
  let ffmpegArgs = [
    '-f', 's16le',                 // Input format (raw PCM)
    '-ar', String(SAMPLE_RATE),    // Sample rate
    '-ac', String(CHANNELS),       // Channel count
    '-i', 'pipe:0',                // Read from stdin
    '-f', STREAM_FORMAT,           // Output format
  ];
  
  // Add bitrate only for lossy formats (not for FLAC or WAV)
  if (STREAM_FORMAT !== 'flac' && STREAM_FORMAT !== 'wav') {
    ffmpegArgs.push('-b:a', BITRATE);
  }
  
  // For FLAC, set compression level for better quality/size tradeoff
  if (STREAM_FORMAT === 'flac') {
    ffmpegArgs.push('-compression_level', '5');
  }
  
  ffmpegArgs.push('-');  // Output to stdout
  
  // Start FFmpeg
  const ffmpeg = spawn('ffmpeg', ffmpegArgs);
  
  // Pipe FFmpeg output to HTTP response
  ffmpeg.stdout.pipe(res);
  
  // Variables for this client's stream
  let fifoReadStream = null;
  let silenceInterval = null;
  let hasReceivedFifoData = false;
  let fifoOpenTimeout = null;
  
  // Function to write silence to FFmpeg when no audio
  function startSilenceGenerator() {
    if (silenceInterval) return;
    
    const silenceBuffer = generateSilence(100); // 100ms of silence
    silenceInterval = setInterval(() => {
      if (!hasReceivedFifoData && ffmpeg && !ffmpeg.killed && ffmpeg.stdin.writable) {
        try {
          ffmpeg.stdin.write(silenceBuffer);
        } catch (e) {
          // Ignore write errors
        }
      }
    }, 100);
  }
  
  // Function to stop silence generator
  function stopSilenceGenerator() {
    if (silenceInterval) {
      clearInterval(silenceInterval);
      silenceInterval = null;
    }
    if (fifoOpenTimeout) {
      clearTimeout(fifoOpenTimeout);
      fifoOpenTimeout = null;
    }
  }
  
  // Try to open FIFO for reading
  function openFifo() {
    if (res._cleanedUp) return;
    
    try {
      // Open FIFO in non-blocking read mode
      const fd = fs.openSync(FIFO_PATH, fs.constants.O_RDONLY | fs.constants.O_NONBLOCK);
      fifoReadStream = fs.createReadStream(null, { fd, highWaterMark: 65536 });
      
      fifoReadStream.on('data', (chunk) => {
        hasReceivedFifoData = true;
        isReceivingAudio = true;
        
        if (ffmpeg && !ffmpeg.killed && ffmpeg.stdin.writable) {
          try {
            ffmpeg.stdin.write(chunk);
          } catch (e) {
            // Ignore write errors
          }
        }
      });
      
      fifoReadStream.on('end', () => {
        // FIFO stream ended (writer closed), silently retry
        hasReceivedFifoData = false;
        isReceivingAudio = false;
        fifoReadStream = null;
        // Reopen FIFO after a short delay
        fifoOpenTimeout = setTimeout(openFifo, 100);
      });
      
      fifoReadStream.on('error', (err) => {
        // EAGAIN is expected for non-blocking read when no data
        if (err.code !== 'EAGAIN') {
          console.log('FIFO read error:', err.code);
        }
        hasReceivedFifoData = false;
        isReceivingAudio = false;
        fifoReadStream = null;
        // Retry opening FIFO
        fifoOpenTimeout = setTimeout(openFifo, 500);
      });
      
    } catch (err) {
      // ENXIO means no writer on FIFO, which is normal when librespot isn't playing
      if (err.code !== 'ENXIO' && err.code !== 'EAGAIN') {
        console.log('Failed to open FIFO:', err.code);
      }
      // Retry opening FIFO
      fifoOpenTimeout = setTimeout(openFifo, 1000);
    }
  }
  
  // Start silence generator if enabled
  if (SILENCE_ON_NO_INPUT) {
    startSilenceGenerator();
  }
  
  // Start trying to read from FIFO
  openFifo();
  
  // Handle FFmpeg stdout pipe errors
  ffmpeg.stdout.on('error', (error) => {
    console.error('FFmpeg stdout error:', error);
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
  
  // Handle FFmpeg errors
  ffmpeg.stderr.on('data', (data) => {
    const msg = data.toString();
    // Only log non-routine messages
    if (!msg.includes('size=') && !msg.includes('time=')) {
      console.log(`FFmpeg: ${msg}`);
    }
  });
  
  ffmpeg.on('error', (error) => {
    console.error('FFmpeg process error:', error);
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
  
  ffmpeg.on('close', (code) => {
    console.log(`FFmpeg process exited with code ${code}`);
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
  
  // Handle stdin errors (important for pipe)
  ffmpeg.stdin.on('error', (error) => {
    if (error.code !== 'EPIPE') {
      console.error('FFmpeg stdin error:', error);
    }
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
  
  // Handle response pipe errors
  res.on('error', (error) => {
    console.error('Response stream error:', error);
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
  
  // Handle client disconnect
  req.on('close', () => {
    console.log('Client disconnected:', req.ip);
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
  
  req.on('error', (error) => {
    console.error('Request error:', error);
    stopSilenceGenerator();
    cleanupFFmpeg(ffmpeg, res, fifoReadStream, silenceInterval);
  });
});

// Root endpoint with info
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>Roon LibreSpot Streamer</title></head>
      <body>
        <h1>Roon LibreSpot Streaming Server</h1>
        <p>Active clients: ${currentClients.size}</p>
        <p>Receiving audio: ${isReceivingAudio}</p>
        <p>Stream URL: <a href="/stream">/stream</a></p>
        <p>Health check: <a href="/health">/health</a></p>
      </body>
    </html>
  `);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Streaming server listening on port ${PORT}`);
  console.log(`Stream URL: http://0.0.0.0:${PORT}/stream`);
  console.log(`Format: ${STREAM_FORMAT}, Bitrate: ${BITRATE}`);
  console.log(`Silence on no input: ${SILENCE_ON_NO_INPUT}`);
  console.log(`Waiting for audio from FIFO: ${FIFO_PATH}`);
});
