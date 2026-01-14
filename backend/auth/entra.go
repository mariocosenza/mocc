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

var userCtxKey = &struct{ name string }{"user_id"}

func GetUserID(ctx context.Context) string {
	val, _ := ctx.Value(userCtxKey).(string)
	return val
}

type EntraConfig struct {
	TenantID         string
	ExpectedAudience string
	RequiredScope    string
	RequireAuth      bool
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
		if v.shouldSkip(r) {
			next.ServeHTTP(w, r)
			return
		}

		oid, status, ok := v.authorize(r)
		if !ok {
			msg := "Unauthorized"
			if status == http.StatusForbidden {
				msg = "Forbidden"
			}
			writeJSONError(w, msg, status)
			return
		}

		ctx := context.WithValue(r.Context(), userCtxKey, oid)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (v *EntraValidator) shouldSkip(r *http.Request) bool {
	if r.URL.Path == "/health" {
		return true
	}
	// Allow OPTIONS requests for CORS preflight
	if r.Method == http.MethodOptions {
		return true
	}
	return !v.cfg.RequireAuth
}

func (v *EntraValidator) authorize(r *http.Request) (string, int, bool) {
	raw := bearerToken(r.Header.Get("Authorization"))
	if raw == "" {
		return "", http.StatusUnauthorized, false
	}

	keyset, err := v.cache.Get(r.Context(), v.jwksURL)
	if err != nil {
		return "", http.StatusUnauthorized, false
	}

	tok, err := jwt.Parse(
		[]byte(raw),
		jwt.WithKeySet(keyset),
		jwt.WithValidate(true),
		jwt.WithAudience(v.cfg.ExpectedAudience),
	)
	if err != nil {
		return "", http.StatusUnauthorized, false
	}

	expectedIss := fmt.Sprintf("https://login.microsoftonline.com/%s/v2.0", v.cfg.TenantID)
	if tok.Issuer() != expectedIss {
		return "", http.StatusUnauthorized, false
	}

	scpVal, _ := tok.Get("scp")
	if !hasSpaceSeparatedValue(scpVal, v.cfg.RequiredScope) {
		return "", http.StatusForbidden, false
	}

	// Extract OID (Object ID) which corresponds to the Microsoft Graph User ID.
	// Use "oid" claim for standard user mapping.
	oidVal, _ := tok.Get("oid")
	oid, ok := oidVal.(string)
	if !ok || oid == "" {
		return "", http.StatusUnauthorized, false
	}

	return oid, 0, true
}

func writeJSONError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	fmt.Fprintf(w, `{"errors": [{"message": "%s"}]}`, msg)
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
