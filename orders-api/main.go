package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

// Version is injected at build time via -ldflags "-X main.Version=<commit>"
var Version = "dev"

type OrderRequest struct {
	CustomerName string   `json:"customer_name"`
	Items        []string `json:"items"`
	Total        float64  `json:"total"`
}

type OrderResponse struct {
	ID           int      `json:"id"`
	CustomerName string   `json:"customer_name"`
	Items        []string `json:"items"`
	Total        float64  `json:"total"`
	Status       string   `json:"status"`
}

type Server struct {
	db    *sql.DB
	redis *redis.Client
}

func (s *Server) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) infoHandler(w http.ResponseWriter, r *http.Request) {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"service": "orders-api",
		"version": Version,
		"pod":     hostname,
	})
}

func (s *Server) ordersHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req OrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request payload", http.StatusBadRequest)
		return
	}
	if req.CustomerName == "" || len(req.Items) == 0 {
		http.Error(w, "customer_name and items are required", http.StatusBadRequest)
		return
	}

	itemsJSON, err := json.Marshal(req.Items)
	if err != nil {
		http.Error(w, "failed to encode items", http.StatusInternalServerError)
		return
	}

	var orderID int
	if s.db != nil {
		err = s.db.QueryRow(
			"INSERT INTO orders (customer_name, items, total, status) VALUES ($1, $2, $3, $4) RETURNING id",
			req.CustomerName, string(itemsJSON), req.Total, "new",
		).Scan(&orderID)
		if err != nil {
			log.Printf("db insert error: %v", err)
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}
	} else {
		orderID = int(time.Now().Unix()%10000) + 1
	}

	resp := OrderResponse{
		ID:           orderID,
		CustomerName: req.CustomerName,
		Items:        req.Items,
		Total:        req.Total,
		Status:       "new",
	}

	if s.redis != nil {
		jobPayload, _ := json.Marshal(resp)
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := s.redis.RPush(ctx, "orders_queue", jobPayload).Err(); err != nil {
			log.Printf("redis enqueue error: %v", err)
			http.Error(w, "queue error", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(resp)
}

func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", s.healthHandler)
	mux.HandleFunc("/info", s.infoHandler)
	mux.HandleFunc("/orders", s.ordersHandler)
	mux.HandleFunc("/api/orders", s.ordersHandler)
	return mux
}

func main() {
	healthcheck := flag.Bool("healthcheck", false, "run HTTP healthcheck and exit")
	flag.Parse()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	if *healthcheck {
		client := &http.Client{Timeout: 2 * time.Second}
		resp, err := client.Get("http://127.0.0.1:" + port + "/health")
		if err != nil || resp.StatusCode != http.StatusOK {
			os.Exit(1)
		}
		os.Exit(0)
	}

	var db *sql.DB
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		var err error
		db, err = sql.Open("postgres", dsn)
		if err != nil {
			log.Fatalf("failed to open db: %v", err)
		}
		defer db.Close()
	}

	var rdb *redis.Client
	if redisAddr := os.Getenv("REDIS_ADDR"); redisAddr != "" {
		rdb = redis.NewClient(&redis.Options{Addr: redisAddr})
		defer rdb.Close()
	}

	srv := &Server{db: db, redis: rdb}

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           srv.routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("orders-api (%s) listening on :%s", Version, port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}
