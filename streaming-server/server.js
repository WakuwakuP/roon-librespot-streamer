const express = require('express');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.STREAMING_PORT || 3000;
const FIFO_PATH = process.env.FIFO_PATH || '/tmp/librespot-audio';
const STREAM_FORMAT = process.env.STREAM_FORMAT || 'mp3';
const BITRATE = process.env.BITRATE || '320k';

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
  if (ffmpeg && !ffmpeg.killed) {
    ffmpeg.kill('SIGTERM');
  }
  currentClients.delete(res);
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
  
  // Start FFmpeg to read from FIFO and encode to desired format
  const ffmpeg = spawn('ffmpeg', [
    '-f', 's16le',           // Input format from librespot (raw PCM)
    '-ar', '44100',          // Sample rate
    '-ac', '2',              // Stereo
    '-i', FIFO_PATH,         // Input from FIFO
    '-f', STREAM_FORMAT,     // Output format
    '-b:a', BITRATE,         // Bitrate
    '-'                      // Output to stdout
  ]);
  
  // Pipe FFmpeg output to HTTP response
  ffmpeg.stdout.pipe(res);
  
  // Handle FFmpeg errors
  ffmpeg.stderr.on('data', (data) => {
    console.log(`FFmpeg: ${data}`);
  });
  
  ffmpeg.on('error', (error) => {
    console.error('FFmpeg error:', error);
  });
  
  ffmpeg.on('close', (code) => {
    console.log(`FFmpeg process exited with code ${code}`);
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
