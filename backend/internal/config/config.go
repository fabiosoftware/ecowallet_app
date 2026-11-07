package config

import (
	"errors"
	"os"
	"strings"
)

type Config struct {
	Env            string
	Addr           string
	AuthMode       string // "dev" ou "firebase"
	AllowedOrigins []string
}

func Load() (Config, error) {
	c := Config{
		Env:      get("APP_ENV", "development"),
		Addr:     get("HTTP_ADDR", ":8080"),
		AuthMode: get("AUTH_MODE", "dev"),
	}
	for _, o := range strings.Split(get("CORS_ALLOWED_ORIGINS", ""), ",") {
		if o = strings.TrimSpace(o); o != "" {
			c.AllowedOrigins = append(c.AllowedOrigins, o)
		}
	}
	if c.Env == "production" && c.AuthMode == "dev" {
		return c, errors.New("AUTH_MODE=dev não é permitido em produção")
	}
	return c, nil
}

func get(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
