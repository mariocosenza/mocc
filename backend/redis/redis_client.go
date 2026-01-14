package redis

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	entraid "github.com/redis/go-redis-entraid"
	"github.com/redis/go-redis/v9"
)

type Config struct {
	RedisURL                string
	ManagedIdentityClientID string
	DialTimeout             time.Duration
	ReadTimeout             time.Duration
	WriteTimeout            time.Duration
}

func NewClient(ctx context.Context, cfg Config) (*redis.Client, func() error, error) {
	if strings.TrimSpace(cfg.RedisURL) == "" {
		return nil, nil, fmt.Errorf("REDIS_URL is required")
	}

	onAzure := isTruthy(os.Getenv("RUNNING_ON_AZURE"))

	// Defaults
	if cfg.DialTimeout == 0 {
		cfg.DialTimeout = 5 * time.Second
	}
	if cfg.ReadTimeout == 0 {
		cfg.ReadTimeout = 3 * time.Second
	}
	if cfg.WriteTimeout == 0 {
		cfg.WriteTimeout = 3 * time.Second
	}

	var opts *redis.Options
	var err error

	if !onAzure {
		opts, err = parseLocalConnectionString(cfg.RedisURL)
		if err != nil {
			return nil, nil, fmt.Errorf("parse local REDIS_URL connection string: %w", err)
		}
		opts.TLSConfig = nil
	} else {
		opts, err = parseAzureEndpoint(cfg.RedisURL)
		if err != nil {
			return nil, nil, fmt.Errorf("parse azure REDIS_URL endpoint: %w", err)
		}

		// Enforce TLS for Azure
		host := hostnameFromAddrOrURL(cfg.RedisURL)
		opts.TLSConfig = &tls.Config{
			MinVersion: tls.VersionTLS12,
			ServerName: host,
		}

		providerOpts := entraid.ManagedIdentityCredentialsProviderOptions{
			CredentialsProviderOptions: entraid.CredentialsProviderOptions{
				ClientID: cfg.ManagedIdentityClientID,
			},
		}
		provider, err := entraid.NewManagedIdentityCredentialsProvider(providerOpts)
		if err != nil {
			return nil, nil, fmt.Errorf("failed to create entra id provider: %w", err)
		}
		opts.StreamingCredentialsProvider = provider
	}

	opts.DialTimeout = cfg.DialTimeout
	opts.ReadTimeout = cfg.ReadTimeout
	opts.WriteTimeout = cfg.WriteTimeout

	client := redis.NewClient(opts)

	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, nil, fmt.Errorf("redis ping failed: %w", err)
	}

	return client, client.Close, nil
}

func isTruthy(s string) bool {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "1", "true", "yes", "y", "on":
		return true
	default:
		return false
	}
}

func parseLocalConnectionString(s string) (*redis.Options, error) {
	parts := strings.Split(s, ",")
	addr := strings.TrimSpace(parts[0])
	if addr == "" {
		return nil, fmt.Errorf("missing address (expected host:port)")
	}

	opts := &redis.Options{Addr: addr}

	for _, p := range parts[1:] {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		kv := strings.SplitN(p, "=", 2)
		if len(kv) != 2 {
			return nil, fmt.Errorf("invalid token %q (expected key=value)", p)
		}
		k := strings.ToLower(strings.TrimSpace(kv[0]))
		v := strings.TrimSpace(kv[1])

		switch k {
		case "password":
			opts.Password = v
		case "username":
			opts.Username = v
		case "db":
			n, err := strconv.Atoi(v)
			if err != nil {
				return nil, fmt.Errorf("invalid db %q", v)
			}
			opts.DB = n
		default:
			// ignore unknown keys to be forward-compatible
		}
	}

	return opts, nil
}

func parseAzureEndpoint(s string) (*redis.Options, error) {
	trim := strings.TrimSpace(s)

	if strings.HasPrefix(trim, "redis://") || strings.HasPrefix(trim, "rediss://") {
		return redis.ParseURL(trim)
	}

	addr, db := trim, 0
	if i := strings.Index(trim, "/"); i >= 0 {
		addr = trim[:i]
		dbStr := trim[i+1:]
		if dbStr != "" {
			n, err := strconv.Atoi(dbStr)
			if err != nil {
				return nil, fmt.Errorf("invalid db in endpoint %q", trim)
			}
			db = n
		}
	}

	if strings.TrimSpace(addr) == "" {
		return nil, fmt.Errorf("missing azure address (expected host:port)")
	}

	return &redis.Options{
		Addr: addr,
		DB:   db,
	}, nil
}

func hostnameFromAddrOrURL(s string) string {
	trim := strings.TrimSpace(s)

	if strings.HasPrefix(trim, "redis://") || strings.HasPrefix(trim, "rediss://") {
		if u, err := url.Parse(trim); err == nil && u.Hostname() != "" {
			return u.Hostname()
		}
	}

	hostport := trim
	if i := strings.Index(hostport, "/"); i >= 0 {
		hostport = hostport[:i]
	}

	if i := strings.LastIndex(hostport, ":"); i > 0 {
		return hostport[:i]
	}
	return hostport
}
