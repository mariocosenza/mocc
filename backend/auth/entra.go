package auth

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
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

	// Normalize TenantID: extract tenant from full URL if provided
	// e.g., "https://login.microsoftonline.com/common" -> "common"
	if strings.Contains(cfg.TenantID, "login.microsoftonline.com/") {
		parts := strings.Split(cfg.TenantID, "login.microsoftonline.com/")
		if len(parts) > 1 {
			cfg.TenantID = strings.TrimSuffix(parts[1], "/")
		}
	}

	log.Printf("auth: Initializing validator with TenantID=%s, Audience=%s, Scope=%s", cfg.TenantID, cfg.ExpectedAudience, cfg.RequiredScope)

	if cfg.TenantID == "" {
		return nil, fmt.Errorf("TENANT_ID is required")
	}
	if cfg.ExpectedAudience == "" {
		return nil, fmt.Errorf("EXPECTED_AUDIENCE is required")
	}
	if cfg.RequiredScope == "" {
		return nil, fmt.Errorf("REQUIRED_SCOPE is required")
	}

	// For multi-tenant apps, register JWKS endpoints for both organizational and personal accounts
	jwksURLCommon := "https://login.microsoftonline.com/common/discovery/v2.0/keys"
	jwksURLConsumers := "https://login.microsoftonline.com/consumers/discovery/v2.0/keys"

	c := jwk.NewCache(context.Background())
	if err := c.Register(jwksURLCommon, jwk.WithMinRefreshInterval(15*time.Minute)); err != nil {
		return nil, err
	}
	if err := c.Register(jwksURLConsumers, jwk.WithMinRefreshInterval(15*time.Minute)); err != nil {
		return nil, err
	}

	return &EntraValidator{
		cfg:     cfg,
		jwksURL: jwksURLCommon, // Primary URL, but we'll try both
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

	// DEBUG: Log all headers to debug missing Authorization issue
	// for k, v := range r.Header {
	// 	log.Printf("auth-debug: %s = %v", k, v)
	// }

	if raw == "" {
		log.Printf("auth: missing Authorization header. Headers: %v", r.Header)
		return "", http.StatusUnauthorized, false
	}

	algStr, kid, err := parseJWTHeader(raw)
	if err != nil {
		log.Printf("auth: failed to parse token header")
		return "", http.StatusUnauthorized, false
	}

	if algStr == "" {
		log.Printf("auth: missing alg in token header")
		return "", http.StatusUnauthorized, false
	}
	if kid == "" {
		log.Printf("auth: missing kid in token header")
		return "", http.StatusUnauthorized, false
	}

	// Do not log 'kid' in clear text. If you need correlation, log a stable hash prefix.
	kidTag := redactTag(kid)

	alg := jwa.SignatureAlgorithm(algStr)
	if alg != jwa.RS256 {
		log.Printf("auth: unexpected token alg (expected RS256)")
		return "", http.StatusUnauthorized, false
	}

	keyset, err := v.cache.Get(r.Context(), v.jwksURL)
	if err != nil {
		log.Printf("auth: failed to get JWKS from primary endpoint")
		return "", http.StatusUnauthorized, false
	}
	logJWKSLoaded(keyset)

	key, ok := keyset.LookupKeyID(kid)

	// If key not found in primary (common), try consumers endpoint for personal accounts
	if !ok || key == nil {
		consumersURL := "https://login.microsoftonline.com/consumers/discovery/v2.0/keys"
		keyset2, err2 := v.cache.Get(r.Context(), consumersURL)
		if err2 == nil {
			log.Printf("auth: trying consumers JWKS endpoint...")
			logJWKSLoaded(keyset2)
			key, ok = keyset2.LookupKeyID(kid)
		}
	}

	if !ok || key == nil {
		log.Printf("auth: no matching JWKS key for token in any endpoint (kid=%s)", kidTag)
		return "", http.StatusUnauthorized, false
	}

	if use, ok := key.Get(jwk.KeyUsageKey); ok {
		if s, _ := use.(string); s != "" && s != "sig" {
			// Do not log the full 'use' value if you don't need it; keep it minimal.
			log.Printf("auth: JWKS key has unexpected usage (kid=%s)", kidTag)
			return "", http.StatusUnauthorized, false
		}
	}

	log.Printf("auth: matching JWKS key found (kid=%s)", kidTag)

	var pub any
	if err := key.Raw(&pub); err != nil {
		log.Printf("auth: failed to extract public key (kid=%s)", kidTag)
		return "", http.StatusUnauthorized, false
	}

	tok, err := jwt.Parse(
		[]byte(raw),
		jwt.WithKey(alg, pub),
		jwt.WithValidate(false),
	)
	if err != nil {
		log.Printf("auth: token signature verification failed")
		return "", http.StatusUnauthorized, false
	}

	// Parse expected audiences (comma-separated)
	audiences := strings.Split(v.cfg.ExpectedAudience, ",")
	for i := range audiences {
		audiences[i] = strings.TrimSpace(audiences[i])
	}

	// Helper function to check if token audience matches any expected audience
	checkAudience := func(tokenAud []string) error {
		for _, ta := range tokenAud {
			for _, ea := range audiences {
				if ta == ea {
					return nil
				}
			}
		}
		return fmt.Errorf("audience mismatch: expected one of %v, got %v", audiences, tokenAud)
	}

	if err := checkAudience(tok.Audience()); err != nil {
		log.Printf("auth: %v", err)
		return "", http.StatusUnauthorized, false
	}

	// For multi-tenant apps, the issuer contains the user's actual tenant ID, not "common"
	// We validate the issuer format rather than exact match
	isMultiTenant := v.cfg.TenantID == "common" || v.cfg.TenantID == "consumers" || v.cfg.TenantID == "organizations"

	if isMultiTenant {
		// Log token claims for debugging
		log.Printf("auth: token audience=%v, expected=%v", tok.Audience(), audiences)
		log.Printf("auth: token issuer=%s", tok.Issuer())
		log.Printf("auth: token expiry=%v, now=%v", tok.Expiration(), time.Now().UTC())

		// Validate expiry, but skip strict issuer check
		if err := jwt.Validate(
			tok,
			jwt.WithAcceptableSkew(2*time.Minute),
		); err != nil {
			log.Printf("auth: token claims validation failed: %v", err)
			return "", http.StatusUnauthorized, false
		}

		// Manually check issuer format
		issuer := tok.Issuer()
		if !strings.HasPrefix(issuer, "https://login.microsoftonline.com/") || !strings.HasSuffix(issuer, "/v2.0") {
			log.Printf("auth: invalid issuer format: %s", issuer)
			return "", http.StatusUnauthorized, false
		}
	} else {
		// Single tenant: strict issuer validation
		expectedIss := fmt.Sprintf("https://login.microsoftonline.com/%s/v2.0", v.cfg.TenantID)

		if err := jwt.Validate(
			tok,
			jwt.WithIssuer(expectedIss),
			jwt.WithAcceptableSkew(2*time.Minute),
		); err != nil {
			log.Printf("auth: token claims validation failed")
			return "", http.StatusUnauthorized, false
		}
	}

	if v.cfg.RequiredScope != "" {
		scpVal, _ := tok.Get("scp")
		rolesVal, _ := tok.Get("roles")
		if !hasSpaceSeparatedValue(scpVal, v.cfg.RequiredScope) && !hasStringArrayValue(rolesVal, v.cfg.RequiredScope) {
			// Do not log scp/roles values.
			log.Printf("auth: scope/role missing (required=%s)", v.cfg.RequiredScope)
			return "", http.StatusForbidden, false
		}
	}

	oidVal, _ := tok.Get("oid")
	oid, ok := oidVal.(string)
	if !ok || oid == "" {
		log.Printf("auth: missing oid claim")
		return "", http.StatusUnauthorized, false
	}

	return oid, 0, true
}

func logJWKSLoaded(keyset jwk.Set) {
	if keyset == nil {
		log.Printf("auth: JWKS keyset is nil")
		return
	}
	// Do not log the list of kids.
	log.Printf("auth: JWKS keyset loaded (keys=%d)", keyset.Len())
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

// redactTag returns a stable, non-reversible tag suitable for logs.
func redactTag(s string) string {
	if s == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(s))
	// 8 bytes => 16 hex chars; enough to correlate without exposing the raw value.
	return hex.EncodeToString(sum[:8])
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
