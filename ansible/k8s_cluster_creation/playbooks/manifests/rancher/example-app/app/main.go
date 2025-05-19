package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
)

type Response struct {
	Message string `json:"message"`
}

var buffer []byte

func init() {
	buffer = make([]byte, 100*1024*1024)
	for i := range buffer {
		buffer[i] = byte(i % 256)
	}
}

func main() {
	http.HandleFunc("/", helloHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/var", varHandler)
	http.HandleFunc("/callInternalMicroservice", callInternalMicroserviceHandler)
	http.ListenAndServe(":8080", nil)
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	// Example to call "http://localhost:8080/"
	serviceName := os.Getenv("NAME_SERVICE")
	var response Response

	if serviceName != "" {
		response = Response{
			Message: "Hello World from service: " + serviceName,
		}
	} else {
		response = Response{
			Message: "Hello World!",
		}
	}

	w.Header().Set("Content-Type", "application/json")

	// Return removed
	json.NewEncoder(w).Encode(response)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	// Example to call "http://localhost:8080/health"
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"healthy"}`))
}

func varHandler(w http.ResponseWriter, r *http.Request) {
	// Example to call "http://localhost:8080/var?key=MY_SECRET"
	key := r.URL.Query().Get("key")

	if key != "" {
		value := os.Getenv(key)
		json.NewEncoder(w).Encode(Response{Message: value})
	} else {
		json.NewEncoder(w).Encode(Response{Message: "Invalid key, not found"})
	}
}

func callInternalMicroserviceHandler(w http.ResponseWriter, r *http.Request) {
	// Example to call "http://localhost:8080/callInternalMicroservice"
	w.Header().Set("Content-Type", "application/json")

	url := os.Getenv("internalUrlMicroservice")
	if url == "" {
		json.NewEncoder(w).Encode(Response{Message: "Missing env var: internalUrlMicroservice"})
		return
	}

	resp, err := http.Get(url)
	if err != nil {
		json.NewEncoder(w).Encode(Response{Message: "Failed to call service: " + err.Error()})
		return
	}
	defer resp.Body.Close()

	io.Copy(w, resp.Body)
}
