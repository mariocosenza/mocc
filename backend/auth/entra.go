package auth

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

type EntraConfig struct {
	TenantID string
	ExpectedAudience string
	RequiredScope string
	RequireAuth bool
}

type EntraValidator struct {
	cfg     EntraConfig
	jwksURL string
	cache   *jwk.Cache
}

func NewEntraValidator(cfg EntraConfig) (*EntraValidator, error) {
	cfg.TenantID = strings.TrimSpace(cfg.TenantID)
	cfg.ExpectedAudience = strings.TrimSpace(cfg.ExpectedAudience)
	cfg.RequiredScope = strings.TrimSpace(cfg.RequiredScope)

	if !cfg.RequireAuth {
		return &EntraValidator{cfg: cfg}, nil
	}

	if cfg.TenantID == "" {
		return nil, fmt.Errorf("TENANT_ID is required when RequireAuth=true")
	}
	if cfg.ExpectedAudience == "" {
		return nil, fmt.Errorf("EXPECTED_AUDIENCE is required when RequireAuth=true")
	}
	if cfg.RequiredScope == "" {
		return nil, fmt.Errorf("REQUIRED_SCOPE is required when RequireAuth=true")
	}

	jwksURL := fmt.Sprintf("https://login.microsoftonline.com/%s/discovery/v2.0/keys", cfg.TenantID)

	c := jwk.NewCache(context.Background())
	if err := c.Register(jwksURL, jwk.WithMinRefreshInterval(15*time.Minute)); err != nil {
		return nil, err
	}

	return &EntraValidator{
		cfg:     cfg,
		jwksURL: jwksURL,
		cache:   c,
	}, nil
}

func (v *EntraValidator) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}

		if !v.cfg.RequireAuth {
			next.ServeHTTP(w, r)
			return
		}

		raw := bearerToken(r.Header.Get("Authorization"))
		if raw == "" {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		keyset, err := v.cache.Get(r.Context(), v.jwksURL)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		tok, err := jwt.Parse(
			[]byte(raw),
			jwt.WithKeySet(keyset),
			jwt.WithValidate(true),
			jwt.WithAudience(v.cfg.ExpectedAudience),
		)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		expectedIss := fmt.Sprintf("https://login.microsoftonline.com/%s/v2.0", v.cfg.TenantID)
		if tok.Issuer() != expectedIss {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		scpVal, _ := tok.Get("scp")
		if !hasSpaceSeparatedValue(scpVal, v.cfg.RequiredScope) {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func bearerToken(h string) string {
	if h == "" {
		return ""
	}
	parts := strings.SplitN(h, " ", 2)
	if len(parts) != 2 {
		return ""
	}
	if !strings.EqualFold(parts[0], "Bearer") {
		return ""
	}
	return strings.TrimSpace(parts[1])
}

func hasSpaceSeparatedValue(val any, required string) bool {
	s, _ := val.(string)
	if s == "" {
		return false
	}
	for _, p := range strings.Fields(s) {
		if p == required {
			return true
		}
	}
	return false
}
