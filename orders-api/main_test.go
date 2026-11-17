package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	srv := &Server{}
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	srv.routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
}

func TestInfoEndpoint(t *testing.T) {
	Version = "test-sha"
	srv := &Server{}
	req := httptest.NewRequest(http.MethodGet, "/info", nil)
	rec := httptest.NewRecorder()

	srv.routes().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode JSON: %v", err)
	}
	if body["version"] != "test-sha" {
		t.Errorf("expected version test-sha, got %s", body["version"])
	}
}

func TestCreateOrderValidationAndSuccess(t *testing.T) {
	srv := &Server{}

	// Invalid payload (missing items)
	badBody := bytes.NewBufferString(`{"customer_name":"Ali"}`)
	badReq := httptest.NewRequest(http.MethodPost, "/api/orders", badBody)
	badRec := httptest.NewRecorder()
	srv.routes().ServeHTTP(badRec, badReq)

	if badRec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for missing items, got %d", badRec.Code)
	}

	// Valid payload
	goodBody := bytes.NewBufferString(`{"customer_name":"Ali","items":["Biryani","Naan"],"total":550}`)
	goodReq := httptest.NewRequest(http.MethodPost, "/api/orders", goodBody)
	goodRec := httptest.NewRecorder()
	srv.routes().ServeHTTP(goodRec, goodReq)

	if goodRec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for valid order, got %d", goodRec.Code)
	}
}
