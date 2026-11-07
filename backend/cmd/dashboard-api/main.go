package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ecowallet/dashboard-api/internal/auth"
	"github.com/ecowallet/dashboard-api/internal/config"
	"github.com/ecowallet/dashboard-api/internal/httpapi"
	"github.com/ecowallet/dashboard-api/internal/service"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	cfg, err := config.Load()
	if err != nil {
		log.Error("configuração inválida", "err", err)
		os.Exit(1)
	}

	var verifier auth.Verifier
	switch cfg.AuthMode {
	case "dev":
		verifier = auth.DevVerifier{}
	default:
		log.Error("AUTH_MODE não suportado (implemente o verificador Firebase)", "mode", cfg.AuthMode)
		os.Exit(1)
	}

	svc := service.NewDashboard(service.MemoryStore{})
	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           httpapi.New(svc, verifier, cfg.AllowedOrigins, log),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Info("servidor iniciado", "addr", cfg.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("falha no servidor", "err", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}
