package auth

import (
	"context"
	"errors"
	"strings"
)

type Claims struct {
	UID       string
	CompanyID string
	Role      string // company_admin | viewer
}

// Verifier valida um bearer token. A implementação de produção deve usar o
// Firebase Admin SDK (VerifyIDToken) e ler company_id/role dos custom claims.
type Verifier interface {
	Verify(ctx context.Context, token string) (Claims, error)
}

var ErrInvalidToken = errors.New("token inválido")

// DevVerifier aceita tokens no formato "dev-<companyID>". Somente para
// desenvolvimento local; a configuração o bloqueia em produção.
type DevVerifier struct{}

func (DevVerifier) Verify(_ context.Context, token string) (Claims, error) {
	company, ok := strings.CutPrefix(token, "dev-")
	if !ok || company == "" {
		return Claims{}, ErrInvalidToken
	}
	return Claims{UID: "dev-user", CompanyID: company, Role: "company_admin"}, nil
}

type ctxKey struct{}

func WithClaims(ctx context.Context, c Claims) context.Context {
	return context.WithValue(ctx, ctxKey{}, c)
}

func FromContext(ctx context.Context) (Claims, bool) {
	c, ok := ctx.Value(ctxKey{}).(Claims)
	return c, ok
}
