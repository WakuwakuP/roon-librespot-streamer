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

let currentClients = new Set();

// Rate limiting middleware to prevent abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

// Apply rate limiting to all routes
app.use(limiter);

// Helper function to cleanup FFmpeg process
function cleanupFFmpeg(ffmpeg, res) {
  // Prevent multiple cleanup attempts
  if (res._cleanedUp) {
    return;
  }
  res._cleanedUp = true;
  
  currentClients.delete(res);
  
  if (ffmpeg && !ffmpeg.killed) {
    try {
      ffmpeg.kill('SIGTERM');
    } catch (error) {
      // Ignore errors if process already exited
      console.log('FFmpeg cleanup: process already terminated');
    }
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    clients: currentClients.size,
    fifo: fs.existsSync(FIFO_PATH)
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
  
  // Build FFmpeg command
  let ffmpegArgs;
  
  if (SILENCE_ON_NO_INPUT) {
    // Generate silence when there's no input from FIFO
    // This approach mixes FIFO input with a continuous silence generator
    // When FIFO has data, it passes through; when empty, silence is output
    const silenceSource = `anullsrc=channel_layout=${CHANNEL_LAYOUT}:sample_rate=${SAMPLE_RATE}`;
    const filterComplex = '[1:a][0:a]amix=inputs=2:duration=longest:dropout_transition=0[out]';
    
    ffmpegArgs = [
      '-f', 'lavfi',
      '-i', silenceSource,           // Continuous silence source
      '-f', 's16le',                 // Input format from librespot (raw PCM)
      '-ar', String(SAMPLE_RATE),    // Sample rate
      '-ac', String(CHANNELS),       // Channel count
      '-i', FIFO_PATH,               // Input from FIFO
      '-filter_complex', filterComplex,
      '-map', '[out]',
      '-f', STREAM_FORMAT,           // Output format
    ];
  } else {
    // Original behavior - block when no input
    ffmpegArgs = [
      '-re',                         // Read input at native frame rate
      '-f', 's16le',                 // Input format from librespot (raw PCM)
      '-ar', String(SAMPLE_RATE),    // Sample rate
      '-ac', String(CHANNELS),       // Channel count
      '-i', FIFO_PATH,               // Input from FIFO
      '-f', STREAM_FORMAT,           // Output format
    ];
  }
  
  // Add bitrate only for lossy formats (not for FLAC or WAV)
  if (STREAM_FORMAT !== 'flac' && STREAM_FORMAT !== 'wav') {
    ffmpegArgs.push('-b:a', BITRATE);
  }
  
  // For FLAC, set compression level for better quality/size tradeoff
  if (STREAM_FORMAT === 'flac') {
    ffmpegArgs.push('-compression_level', '5');
  }
  
  ffmpegArgs.push('-');  // Output to stdout
  
  // Start FFmpeg to read from FIFO and encode to desired format
  const ffmpeg = spawn('ffmpeg', ffmpegArgs);
  
  // Pipe FFmpeg output to HTTP response
  ffmpeg.stdout.pipe(res);
  
  // Handle FFmpeg stdout pipe errors
  ffmpeg.stdout.on('error', (error) => {
    console.error('FFmpeg stdout error:', error);
    cleanupFFmpeg(ffmpeg, res);
  });
  
  // Handle FFmpeg errors
  ffmpeg.stderr.on('data', (data) => {
    console.log(`FFmpeg: ${data}`);
  });
  
  ffmpeg.on('error', (error) => {
    console.error('FFmpeg process error:', error);
    cleanupFFmpeg(ffmpeg, res);
  });
  
  ffmpeg.on('close', (code) => {
    console.log(`FFmpeg process exited with code ${code}`);
    cleanupFFmpeg(ffmpeg, res);
  });
  
  // Handle response pipe errors
  res.on('error', (error) => {
    console.error('Response stream error:', error);
    cleanupFFmpeg(ffmpeg, res);
  });
  
  // Handle client disconnect
  req.on('close', () => {
    console.log('Client disconnected:', req.ip);
    cleanupFFmpeg(ffmpeg, res);
  });
  
  req.on('error', (error) => {
    console.error('Request error:', error);
    cleanupFFmpeg(ffmpeg, res);
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
  console.log(`Waiting for audio from FIFO: ${FIFO_PATH}`);
});
