package httpapi

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/ecowallet/dashboard-api/internal/auth"
	"github.com/ecowallet/dashboard-api/internal/service"
)

type Server struct {
	svc            *service.Dashboard
	verifier       auth.Verifier
	allowedOrigins []string
	log            *slog.Logger
}

func New(svc *service.Dashboard, v auth.Verifier, origins []string, log *slog.Logger) http.Handler {
	s := &Server{svc: svc, verifier: v, allowedOrigins: origins, log: log}
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})
	mux.Handle("GET /v1/companies/{id}/carbon/summary", s.authed(http.HandlerFunc(s.summary)))
	mux.Handle("GET /v1/companies/{id}/carbon/timeseries", s.authed(http.HandlerFunc(s.timeseries)))

	return s.recoverer(s.cors(s.logging(mux)))
}

func (s *Server) summary(w http.ResponseWriter, r *http.Request) {
	from, to, ok := period(w, r)
	if !ok {
		return
	}
	out, err := s.svc.Summary(r.Context(), r.PathValue("id"), from, to)
	s.respond(w, out, err)
}

func (s *Server) timeseries(w http.ResponseWriter, r *http.Request) {
	from, to, ok := period(w, r)
	if !ok {
		return
	}
	out, err := s.svc.Timeseries(r.Context(), r.PathValue("id"), from, to)
	s.respond(w, out, err)
}

func (s *Server) respond(w http.ResponseWriter, v any, err error) {
	switch {
	case errors.Is(err, service.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", err.Error())
	case err != nil:
		s.log.Error("falha no serviço", "err", err)
		writeError(w, http.StatusInternalServerError, "internal", "erro interno")
	default:
		writeJSON(w, http.StatusOK, v)
	}
}

// period lê ?from=&to= (YYYY-MM-DD). Padrão: últimos 30 dias.
func period(w http.ResponseWriter, r *http.Request) (time.Time, time.Time, bool) {
	to := time.Now().UTC().Truncate(24 * time.Hour)
	from := to.AddDate(0, 0, -30)
	var err error
	if v := r.URL.Query().Get("from"); v != "" {
		if from, err = time.Parse(time.DateOnly, v); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_from", "from deve ser YYYY-MM-DD")
			return from, to, false
		}
	}
	if v := r.URL.Query().Get("to"); v != "" {
		if to, err = time.Parse(time.DateOnly, v); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_to", "to deve ser YYYY-MM-DD")
			return from, to, false
		}
	}
	if from.After(to) {
		writeError(w, http.StatusBadRequest, "invalid_range", "from deve ser anterior a to")
		return from, to, false
	}
	return from, to, true
}

func (s *Server) authed(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || token == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "token ausente")
			return
		}
		claims, err := s.verifier.Verify(r.Context(), token)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthorized", "token inválido")
			return
		}
		// Isolamento por empresa: impede acesso a dados de outra empresa (IDOR).
		if claims.CompanyID != r.PathValue("id") {
			writeError(w, http.StatusForbidden, "forbidden", "acesso negado à empresa")
			return
		}
		next.ServeHTTP(w, r.WithContext(auth.WithClaims(r.Context(), claims)))
	})
}

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		for _, o := range s.allowedOrigins {
			if o == origin {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Vary", "Origin")
				w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
				w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
			}
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		s.log.Info("request", "method", r.Method, "path", r.URL.Path, "dur", time.Since(start))
	})
}

func (s *Server) recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				s.log.Error("panic", "err", rec)
				writeError(w, http.StatusInternalServerError, "internal", "erro interno")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, map[string]string{"code": code, "message": msg})
}
