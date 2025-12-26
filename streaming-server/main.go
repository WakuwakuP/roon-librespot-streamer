package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

const (
	defaultPort       = 8080
	defaultBindAddr   = "0.0.0.0"
	bufferSize        = 8192
	maxClients        = 10
	clientTimeout     = 30 * time.Second
)

type StreamServer struct {
	clients     map[chan []byte]bool
	clientsLock sync.RWMutex
	input       io.Reader
	logger      *log.Logger
}

func NewStreamServer(input io.Reader, logger *log.Logger) *StreamServer {
	return &StreamServer{
		clients: make(map[chan []byte]bool),
		input:   input,
		logger:  logger,
	}
}

func (s *StreamServer) addClient(ch chan []byte) error {
	s.clientsLock.Lock()
	defer s.clientsLock.Unlock()

	if len(s.clients) >= maxClients {
		return fmt.Errorf("maximum number of clients (%d) reached", maxClients)
	}

	s.clients[ch] = true
	s.logger.Printf("Client connected. Total clients: %d", len(s.clients))
	return nil
}

func (s *StreamServer) removeClient(ch chan []byte) {
	s.clientsLock.Lock()
	defer s.clientsLock.Unlock()

	if _, ok := s.clients[ch]; ok {
		delete(s.clients, ch)
		close(ch)
		s.logger.Printf("Client disconnected. Total clients: %d", len(s.clients))
	}
}

func (s *StreamServer) broadcast() {
	buffer := make([]byte, bufferSize)
	consecutiveErrors := 0
	maxConsecutiveErrors := 5
	
	for {
		n, err := s.input.Read(buffer)
		if err != nil {
			consecutiveErrors++
			if err == io.EOF {
				s.logger.Println("Input stream ended")
			} else {
				s.logger.Printf("Error reading from input: %v", err)
			}
			
			// Implement exponential backoff for repeated errors
			if consecutiveErrors >= maxConsecutiveErrors {
				backoff := time.Duration(consecutiveErrors-maxConsecutiveErrors+1) * time.Second
				if backoff > 30*time.Second {
					backoff = 30 * time.Second
				}
				s.logger.Printf("Multiple consecutive errors (%d), backing off for %v", consecutiveErrors, backoff)
				time.Sleep(backoff)
			} else {
				time.Sleep(1 * time.Second)
			}
			continue
		}

		// Reset error counter on successful read
		consecutiveErrors = 0

		if n > 0 {
			data := make([]byte, n)
			copy(data, buffer[:n])

			s.clientsLock.RLock()
			for ch := range s.clients {
				select {
				case ch <- data:
					// Successfully sent to client
				default:
					// Channel is full, client is slow
					s.logger.Printf("Warning: Client channel full, dropping packet (slow client)")
				}
			}
			s.clientsLock.RUnlock()
		}
	}
}

func (s *StreamServer) handleStream(w http.ResponseWriter, r *http.Request) {
	// Set headers for FLAC streaming
	w.Header().Set("Content-Type", "audio/flac")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Transfer-Encoding", "chunked")

	// Check if we can flush
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		s.logger.Println("Error: ResponseWriter does not support flushing")
		return
	}

	// Create a channel for this client
	clientChan := make(chan []byte, 100)
	
	if err := s.addClient(clientChan); err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		s.logger.Printf("Error adding client: %v", err)
		return
	}
	defer s.removeClient(clientChan)

	s.logger.Printf("New stream request from %s", r.RemoteAddr)

	// Set up a timeout for slow clients
	timeout := time.NewTimer(clientTimeout)
	defer timeout.Stop()

	// Stream data to client
	for {
		select {
		case data, ok := <-clientChan:
			if !ok {
				return
			}
			
			// Reset timeout on successful write
			timeout.Reset(clientTimeout)
			
			if _, err := w.Write(data); err != nil {
				s.logger.Printf("Error writing to client %s: %v", r.RemoteAddr, err)
				return
			}
			flusher.Flush()

		case <-timeout.C:
			s.logger.Printf("Client %s timed out", r.RemoteAddr)
			return

		case <-r.Context().Done():
			s.logger.Printf("Client %s context cancelled", r.RemoteAddr)
			return
		}
	}
}

func (s *StreamServer) handleHealth(w http.ResponseWriter, r *http.Request) {
	s.clientsLock.RLock()
	clientCount := len(s.clients)
	s.clientsLock.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"ok","clients":%d,"max_clients":%d}`, clientCount, maxClients)
}

func (s *StreamServer) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	s.clientsLock.RLock()
	clientCount := len(s.clients)
	s.clientsLock.RUnlock()

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	
	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
    <title>Roon Librespot FLAC Streamer</title>
    <meta charset="utf-8">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #1db954;
            padding-bottom: 10px;
        }
        .status {
            background: #e8f5e9;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .endpoint {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
            font-family: monospace;
        }
        .info {
            color: #666;
            margin: 10px 0;
        }
        a {
            color: #1db954;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎵 Roon Librespot FLAC Streamer</h1>
        
        <div class="status">
            <strong>Status:</strong> Running<br>
            <strong>Connected Clients:</strong> %d / %d
        </div>

        <h2>Available Endpoints</h2>
        
        <div class="endpoint">
            <strong>GET /stream</strong><br>
            <span class="info">FLAC audio stream (audio/flac)</span><br>
            <a href="/stream">Open stream</a>
        </div>

        <div class="endpoint">
            <strong>GET /health</strong><br>
            <span class="info">Health check endpoint (application/json)</span><br>
            <a href="/health">Check health</a>
        </div>

        <h2>Usage</h2>
        <p class="info">
            To play the stream, use a media player that supports FLAC streaming:
        </p>
        <div class="endpoint">
            <strong>VLC:</strong> File → Open Network Stream → http://%s:%s/stream<br>
            <strong>mpv:</strong> mpv http://%s:%s/stream<br>
            <strong>ffplay:</strong> ffplay http://%s:%s/stream
        </div>

        <h2>Notes</h2>
        <p class="info">
            • Maximum %d concurrent clients supported<br>
            • Stream format: FLAC (44.1kHz, 16-bit, stereo)<br>
            • Client timeout: %v<br>
            • Connect your Spotify app to "Roon Librespot FLAC Streamer" to start streaming
        </p>
    </div>
</body>
</html>`, clientCount, maxClients, getHostname(), getPort(), getHostname(), getPort(), getHostname(), getPort(), maxClients, clientTimeout)

	fmt.Fprint(w, html)
}

func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "localhost"
	}
	return hostname
}

func getPort() string {
	port := os.Getenv("HTTP_PORT")
	if port == "" {
		port = strconv.Itoa(defaultPort)
	}
	return port
}

func main() {
	// Configure logger
	logger := log.New(os.Stderr, "[StreamServer] ", log.LstdFlags)

	// Get configuration from environment
	port := defaultPort
	if portEnv := os.Getenv("HTTP_PORT"); portEnv != "" {
		if p, err := strconv.Atoi(portEnv); err == nil {
			port = p
		} else {
			logger.Printf("Warning: Invalid HTTP_PORT value '%s', using default %d", portEnv, defaultPort)
		}
	}

	bindAddr := defaultBindAddr
	if bindEnv := os.Getenv("HTTP_BIND_ADDR"); bindEnv != "" {
		bindAddr = bindEnv
	}

	addr := fmt.Sprintf("%s:%d", bindAddr, port)

	logger.Printf("Starting FLAC streaming server on %s", addr)
	logger.Printf("Maximum concurrent clients: %d", maxClients)
	logger.Printf("Client timeout: %v", clientTimeout)

	// Create streaming server
	server := NewStreamServer(os.Stdin, logger)

	// Start broadcasting from stdin
	go server.broadcast()

	// Set up HTTP handlers
	http.HandleFunc("/stream", server.handleStream)
	http.HandleFunc("/health", server.handleHealth)
	http.HandleFunc("/", server.handleRoot)

	// Start HTTP server
	logger.Printf("Server ready. Stream available at: http://%s/stream", addr)
	
	if err := http.ListenAndServe(addr, nil); err != nil {
		logger.Fatalf("Server error: %v", err)
	}
}
