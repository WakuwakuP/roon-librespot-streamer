#!/usr/bin/env python3
"""
Stream Mixer - Ensures continuous audio streaming by mixing librespot output with silence.

This script reads from a named pipe (librespot's PCM output) with a timeout.
When data is available, it forwards the real audio. When no data is available
(e.g., librespot is idle or has errors), it generates silent PCM audio to keep
the stream alive and prevent client timeouts.

Input: Named pipe with s16le PCM audio at 44.1kHz stereo
Output: stdout with s16le PCM audio at 44.1kHz stereo (continuous stream)
"""

import sys
import os
import time
import select
import struct

# Audio parameters
SAMPLE_RATE = 44100
CHANNELS = 2
SAMPLE_SIZE = 2  # 16-bit = 2 bytes
CHUNK_SAMPLES = 4410  # 0.1 second of audio
CHUNK_SIZE = CHUNK_SAMPLES * CHANNELS * SAMPLE_SIZE
READ_TIMEOUT = 0.1  # seconds

# Silent audio chunk (all zeros)
SILENT_CHUNK = b'\x00' * CHUNK_SIZE


def log(message):
    """Log to stderr to avoid corrupting the audio stream on stdout."""
    print(f"[StreamMixer] {message}", file=sys.stderr, flush=True)


def read_with_timeout(fd, size, timeout):
    """
    Read from file descriptor with timeout.
    Returns data if available, None if timeout, or raises exception on error.
    """
    ready, _, _ = select.select([fd], [], [], timeout)
    if ready:
        try:
            data = os.read(fd, size)
            return data if data else None
        except OSError as e:
            if e.errno == 11:  # EAGAIN - no data available
                return None
            raise
    return None


def main():
    pipe_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/audio/librespot.pcm'
    
    log(f"Starting stream mixer for pipe: {pipe_path}")
    log(f"Audio format: s16le, {SAMPLE_RATE}Hz, {CHANNELS} channels")
    log(f"Chunk size: {CHUNK_SIZE} bytes ({CHUNK_SAMPLES} samples, {CHUNK_SAMPLES/SAMPLE_RATE:.3f}s)")
    
    consecutive_silent_chunks = 0
    consecutive_audio_chunks = 0
    
    while True:
        pipe = None
        try:
            # Try to open the pipe
            # This will block until librespot opens it for writing
            # We'll stream silence while waiting in the exception handler
            log(f"Waiting to open pipe: {pipe_path}")
            
            # Open with a timeout using a non-blocking approach
            # First, try to open non-blocking to check existence
            try:
                fd = os.open(pipe_path, os.O_RDONLY | os.O_NONBLOCK)
            except FileNotFoundError:
                raise FileNotFoundError(f"Pipe not found: {pipe_path}")
            
            # Now we have the pipe open, make it non-blocking for reading
            pipe = os.fdopen(fd, 'rb', buffering=0)
            log("Pipe opened successfully, starting to read...")
            
            while True:
                # Try to read real audio data with timeout
                data = read_with_timeout(pipe.fileno(), CHUNK_SIZE, READ_TIMEOUT)
                
                if data and len(data) > 0:
                    # Real audio data available
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
                    
                    if consecutive_silent_chunks > 0:
                        log(f"Audio resumed after {consecutive_silent_chunks} silent chunks ({consecutive_silent_chunks * CHUNK_SAMPLES/SAMPLE_RATE:.1f}s)")
                    consecutive_silent_chunks = 0
                    consecutive_audio_chunks += 1
                    
                    # Log audio activity every 10 seconds
                    if consecutive_audio_chunks % 100 == 0:
                        log(f"Streaming audio... ({consecutive_audio_chunks * CHUNK_SAMPLES/SAMPLE_RATE:.1f}s)")
                else:
                    # No data available, send silence
                    sys.stdout.buffer.write(SILENT_CHUNK)
                    sys.stdout.buffer.flush()
                    
                    if consecutive_audio_chunks > 0:
                        log(f"No audio data, streaming silence (was active for {consecutive_audio_chunks * CHUNK_SAMPLES/SAMPLE_RATE:.1f}s)")
                    consecutive_audio_chunks = 0
                    consecutive_silent_chunks += 1
                    
                    # Log silence every 30 seconds
                    if consecutive_silent_chunks % 300 == 1:
                        log(f"Streaming silence... ({consecutive_silent_chunks * CHUNK_SAMPLES/SAMPLE_RATE:.1f}s)")
                
                # Small delay to avoid busy loop when streaming silence
                if data is None or len(data) == 0:
                    time.sleep(0.01)
                    
        except FileNotFoundError:
            log(f"Pipe not found: {pipe_path}, creating and streaming silence...")
            # Stream silence while waiting for pipe
            for _ in range(10):  # 1 second of silence
                sys.stdout.buffer.write(SILENT_CHUNK)
                sys.stdout.buffer.flush()
                time.sleep(0.1)
        except (BrokenPipeError, OSError) as e:
            log(f"Pipe error: {e}, will reopen and stream silence...")
            # Close the pipe if it's open
            if pipe:
                try:
                    pipe.close()
                except:
                    pass
            # Stream silence during reconnection
            for _ in range(10):  # 1 second of silence
                sys.stdout.buffer.write(SILENT_CHUNK)
                sys.stdout.buffer.flush()
                time.sleep(0.1)
        except KeyboardInterrupt:
            log("Interrupted, exiting...")
            if pipe:
                try:
                    pipe.close()
                except:
                    pass
            break
        except Exception as e:
            log(f"Unexpected error: {e}, will retry with silence...")
            if pipe:
                try:
                    pipe.close()
                except:
                    pass
            # Stream silence
            for _ in range(10):  # 1 second of silence
                sys.stdout.buffer.write(SILENT_CHUNK)
                sys.stdout.buffer.flush()
                time.sleep(0.1)


if __name__ == '__main__':
    main()
