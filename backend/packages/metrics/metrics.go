package metrics

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HttpRequestsTotal counts every HTTP request by method, path and response status.
	HttpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests.",
		},
		[]string{"method", "path", "status_code"},
	)

	// HttpRequestDurationSeconds tracks request latency as a histogram.
	// The bucket boundaries match the Grafana dashboard PromQL expectations.
	HttpRequestDurationSeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds.",
			Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10},
		},
		[]string{"method", "path"},
	)

	// ActiveUserRegistrationsTotal is the custom application metric required by Sherlock Logs.
	// It counts the cumulative number of successful user registrations since startup.
	ActiveUserRegistrationsTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "active_user_registrations_total",
			Help: "Total number of successful user registrations.",
		},
	)
)

// Middleware returns a Fiber middleware that records HTTP request metrics.
// It captures: request count (by method, path, status), and request duration (by method, path).
// The /api/prom_metrics path itself is excluded to avoid self-referential noise.
func Middleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		path := c.Path()

		// Do not record metrics for the metrics endpoint itself.
		if path == "/api/prom_metrics" {
			return c.Next()
		}

		start := time.Now()
		err := c.Next()
		duration := time.Since(start).Seconds()

		status := strconv.Itoa(c.Response().StatusCode())
		method := c.Method()

		HttpRequestsTotal.WithLabelValues(method, path, status).Inc()
		HttpRequestDurationSeconds.WithLabelValues(method, path).Observe(duration)

		return err
	}
}
