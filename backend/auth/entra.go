package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/lestrrat-go/jwx/v2/jwa"
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

	if cfg.TenantID == "" {
		return nil, fmt.Errorf("TENANT_ID is required")
	}
	if cfg.ExpectedAudience == "" {
		return nil, fmt.Errorf("EXPECTED_AUDIENCE is required")
	}
	if cfg.RequiredScope == "" {
		return nil, fmt.Errorf("REQUIRED_SCOPE is required")
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
	if r.Method == http.MethodOptions {
		return true
	}
	return false
}

func (v *EntraValidator) authorize(r *http.Request) (string, int, bool) {
	raw := bearerToken(r.Header.Get("Authorization"))
	if raw == "" {
		fmt.Printf("auth: missing Authorization header\n")
		return "", http.StatusUnauthorized, false
	}

	algStr, kid := logTokenHeader(raw)
	logTokenClaimsUnsafe(raw)

	if algStr == "" {
		fmt.Printf("auth: missing alg in token header\n")
		return "", http.StatusUnauthorized, false
	}
	if kid == "" {
		fmt.Printf("auth: missing kid in token header\n")
		return "", http.StatusUnauthorized, false
	}

	alg := jwa.SignatureAlgorithm(algStr)
	if alg != jwa.RS256 {
		fmt.Printf("auth: unexpected token alg=%s (expected RS256)\n", algStr)
		return "", http.StatusUnauthorized, false
	}

	keyset, err := v.cache.Get(r.Context(), v.jwksURL)
	if err != nil {
		fmt.Printf("auth: failed to get JWKS: %v\n", err)
		return "", http.StatusUnauthorized, false
	}
	logKeysetKids(keyset)

	key, ok := keyset.LookupKeyID(kid)
	if !ok || key == nil {
		fmt.Printf("auth: no matching JWKS key for kid=%s\n", kid)
		return "", http.StatusUnauthorized, false
	}

	if use, ok := key.Get(jwk.KeyUsageKey); ok {
		if s, _ := use.(string); s != "" && s != "sig" {
			fmt.Printf("auth: key kid=%s has unexpected use=%v\n", kid, use)
			return "", http.StatusUnauthorized, false
		}
	}

	fmt.Printf("auth: matching JWKS key found for kid=%s (alg=%s)\n", kid, algStr)

	var pub any
	if err := key.Raw(&pub); err != nil {
		fmt.Printf("auth: failed to extract public key for kid=%s: %v\n", kid, err)
		return "", http.StatusUnauthorized, false
	}

	tok, err := jwt.Parse(
		[]byte(raw),
		jwt.WithKey(alg, pub),
		jwt.WithValidate(false),
	)
	if err != nil {
		fmt.Printf("auth: token signature verification failed: %v\n", err)
		return "", http.StatusUnauthorized, false
	}

	expectedIss := fmt.Sprintf("https://login.microsoftonline.com/%s/v2.0", v.cfg.TenantID)

	if err := jwt.Validate(
		tok,
		jwt.WithAudience(v.cfg.ExpectedAudience),
		jwt.WithIssuer(expectedIss),
		jwt.WithAcceptableSkew(2*time.Minute),
	); err != nil {
		fmt.Printf("auth: token claims validation failed: %v\n", err)
		return "", http.StatusUnauthorized, false
	}

	if v.cfg.RequiredScope != "" {
		scpVal, _ := tok.Get("scp")
		rolesVal, _ := tok.Get("roles")
		if !hasSpaceSeparatedValue(scpVal, v.cfg.RequiredScope) && !hasStringArrayValue(rolesVal, v.cfg.RequiredScope) {
			fmt.Printf("auth: scope/role missing. required=%s scp=%v roles=%v\n", v.cfg.RequiredScope, scpVal, rolesVal)
			return "", http.StatusForbidden, false
		}
	}

	oidVal, _ := tok.Get("oid")
	oid, ok := oidVal.(string)
	if !ok || oid == "" {
		fmt.Printf("auth: missing oid claim\n")
		return "", http.StatusUnauthorized, false
	}

	return oid, 0, true
}

func logTokenClaimsUnsafe(raw string) {
	tok, err := jwt.Parse([]byte(raw), jwt.WithVerify(false), jwt.WithValidate(false))
	if err != nil {
		fmt.Printf("auth: failed to parse token without verify: %v\n", err)
		return
	}
	aud := tok.Audience()
	iss := tok.Issuer()
	fmt.Printf("auth: token claims (unverified) iss=%s aud=%v\n", iss, aud)
}

func logKeysetKids(keyset jwk.Set) {
	if keyset == nil {
		fmt.Printf("auth: JWKS keyset is nil\n")
		return
	}
	var kids []string
	for i := 0; i < keyset.Len(); i++ {
		k, ok := keyset.Key(i)
		if !ok {
			continue
		}
		if kid, ok := k.Get(jwk.KeyIDKey); ok {
			if s, ok := kid.(string); ok {
				kids = append(kids, s)
			}
		}
	}
	fmt.Printf("auth: JWKS kids=%v\n", kids)
}

func logTokenHeader(raw string) (string, string) {
	alg, kid, err := parseJWTHeader(raw)
	if err != nil {
		fmt.Printf("auth: failed to parse token header: %v\n", err)
		return "", ""
	}
	fmt.Printf("auth: token header alg=%s kid=%s\n", alg, kid)
	return alg, kid
}

func parseJWTHeader(raw string) (string, string, error) {
	parts := strings.Split(raw, ".")
	if len(parts) < 2 {
		return "", "", fmt.Errorf("invalid jwt format")
	}
	decoded, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return "", "", err
	}
	var hdr map[string]any
	if err := json.Unmarshal(decoded, &hdr); err != nil {
		return "", "", err
	}
	alg, _ := hdr["alg"].(string)
	kid, _ := hdr["kid"].(string)
	return alg, kid, nil
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

func hasStringArrayValue(val any, required string) bool {
	arr, ok := val.([]any)
	if !ok {
		return false
	}
	for _, v := range arr {
		s, _ := v.(string)
		if s == required {
			return true
		}
	}
	return false
}
