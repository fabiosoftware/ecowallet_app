package domain

import "time"

type CarbonSummary struct {
	CompanyID       string    `json:"company_id"`
	From            time.Time `json:"from"`
	To              time.Time `json:"to"`
	TotalBalance    float64   `json:"total_balance"`
	TotalCO2eKg     float64   `json:"total_co2e_kg"`
	Co2SavedKg      float64   `json:"co2_saved_kg"`
	TreesEquivalent int       `json:"trees_equivalent"`
	ActiveUsers     int       `json:"active_users"`
	FactorVersion   string    `json:"factor_version"`
}

type TimeseriesPoint struct {
	Period     string  `json:"period"` // YYYY-MM
	EmittedKg  float64 `json:"emitted_kg"`
	MitigateKg float64 `json:"mitigated_kg"`
}

type Timeseries struct {
	CompanyID string            `json:"company_id"`
	Points    []TimeseriesPoint `json:"points"`
}
