package service

import (
	"context"
	"errors"
	"time"

	"github.com/ecowallet/dashboard-api/internal/domain"
)

var ErrNotFound = errors.New("empresa não encontrada")

// Store é a porta de persistência. Troque a implementação em memória por
// Postgres (pgx) sem alterar handlers ou serviço.
type Store interface {
	Summary(ctx context.Context, companyID string, from, to time.Time) (domain.CarbonSummary, error)
	Timeseries(ctx context.Context, companyID string, from, to time.Time) (domain.Timeseries, error)
}

type Dashboard struct{ store Store }

func NewDashboard(s Store) *Dashboard { return &Dashboard{store: s} }

func (d *Dashboard) Summary(ctx context.Context, companyID string, from, to time.Time) (domain.CarbonSummary, error) {
	return d.store.Summary(ctx, companyID, from, to)
}

func (d *Dashboard) Timeseries(ctx context.Context, companyID string, from, to time.Time) (domain.Timeseries, error) {
	return d.store.Timeseries(ctx, companyID, from, to)
}

// MemoryStore devolve dados fictícios determinísticos para qualquer empresa.
// Os valores NÃO são inventário de emissões (ver ESG_FRAMEWORK.md).
type MemoryStore struct{}

func (MemoryStore) Summary(_ context.Context, id string, from, to time.Time) (domain.CarbonSummary, error) {
	return domain.CarbonSummary{
		CompanyID: id, From: from, To: to,
		TotalBalance: 1250.75, TotalCO2eKg: 420.5, Co2SavedKg: 34.2,
		TreesEquivalent: 5, ActiveUsers: 128, FactorVersion: "gamification-v1",
	}, nil
}

func (MemoryStore) Timeseries(_ context.Context, id string, _, _ time.Time) (domain.Timeseries, error) {
	return domain.Timeseries{CompanyID: id, Points: []domain.TimeseriesPoint{
		{Period: "2026-09", EmittedKg: 130.2, MitigateKg: 10.1},
		{Period: "2026-10", EmittedKg: 140.8, MitigateKg: 11.7},
		{Period: "2026-11", EmittedKg: 149.5, MitigateKg: 12.4},
	}}, nil
}
