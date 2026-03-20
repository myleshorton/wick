package fetch

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCheckRobots_Allowed(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.Write([]byte("User-agent: *\nDisallow: /private/\n"))
			return
		}
		w.Write([]byte("OK"))
	}))
	defer srv.Close()

	client := srv.Client()

	allowed, err := CheckRobots(client, srv.URL+"/public/page")
	if err != nil {
		t.Fatal(err)
	}
	if !allowed {
		t.Error("expected /public/page to be allowed")
	}
}

func TestCheckRobots_Disallowed(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.Write([]byte("User-agent: *\nDisallow: /private/\n"))
			return
		}
		w.Write([]byte("OK"))
	}))
	defer srv.Close()

	client := srv.Client()

	allowed, err := CheckRobots(client, srv.URL+"/private/secret")
	if err != nil {
		t.Fatal(err)
	}
	if allowed {
		t.Error("expected /private/secret to be disallowed")
	}
}

func TestCheckRobots_NoRobotsTxt(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.WriteHeader(404)
			return
		}
		w.Write([]byte("OK"))
	}))
	defer srv.Close()

	client := srv.Client()

	allowed, err := CheckRobots(client, srv.URL+"/anything")
	if err != nil {
		t.Fatal(err)
	}
	if !allowed {
		t.Error("expected everything to be allowed when robots.txt is missing")
	}
}

func TestCheckRobots_WickAgent(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.Write([]byte("User-agent: Wick\nDisallow: /\n\nUser-agent: *\nAllow: /\n"))
			return
		}
		w.Write([]byte("OK"))
	}))
	defer srv.Close()

	client := srv.Client()

	allowed, err := CheckRobots(client, srv.URL+"/page")
	if err != nil {
		t.Fatal(err)
	}
	if allowed {
		t.Error("expected Wick-specific disallow to block the request")
	}
}
