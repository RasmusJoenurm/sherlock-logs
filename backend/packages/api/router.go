package api

import (
	"database/sql"
	"net/http"

	"backend/packages/config"
	"backend/packages/metrics"

	"github.com/gofiber/adaptor/v2"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func WithDB(fn func(c *fiber.Ctx, db *sql.DB) error, db *sql.DB) func(c *fiber.Ctx) error {
	return func(c *fiber.Ctx) error {
		return fn(c, db)
	}
}

func httpServer(db *sql.DB) *fiber.App {
	app := fiber.New()
	app.Use(logger.New())
	app.Use(requestid.New())
	app.Use(metrics.Middleware())

	api := app.Group("/api")
	api.Use(cors.New(cors.Config{
		AllowOrigins:     config.Config[config.CLIENT_URL],
		AllowCredentials: true,
		AllowHeaders:     "Content-Type, Content-Length, Accept-Encoding, Authorization, accept, origin",
		AllowMethods:     "POST, OPTIONS, GET, PUT",
		ExposeHeaders:    "Set-Cookie",
	}))

	api.Get("/ping", Pong)
	api.Get("/health", Health)

	// Prometheus metrics endpoint — scraped by the backend ServiceMonitor every 15s.
	api.Get("/prom_metrics", adaptor.HTTPHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		promhttp.Handler().ServeHTTP(w, r)
	})))

	api.Post("/login", WithDB(Login, db))
	api.Post("/register", WithDB(CreateUser, db))
	api.Get("/logout", Logout)

	api.Get("/session", AuthorizeSession, WithDB(Session, db))

	return app
}
