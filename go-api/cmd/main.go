package main

import (
	"log"
	"os"
	"path/filepath"

	"github.com/joho/godotenv"

	"go-api/internal/infrastructure/database"

	"go-api/internal/infrastructure/handlers"
	"go-api/internal/infrastructure/middleware"
	"go-api/internal/infrastructure/repository"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	err := godotenv.Load()

	if err != nil {
		log.Println(".env file not found, using system environment variables")
	}

	dsn := getEnv("DATABASE_URL", "")
	port := getEnv("PORT", "8080")
	webDir := getEnv("WEB_DIR", "../flutter_app/build/web")

	db := database.NewDatabase(dsn)

	userRepo := repository.NewUserRepository(db)
	userHandler := handlers.NewUserHandler(userRepo)

	r := gin.Default()

	r.Use(cors.New(cors.Config{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{
			"GET",
			"POST",
			"PUT",
			"DELETE",
			"OPTIONS",
		},
		AllowHeaders: []string{
			"Origin",
			"Content-Type",
			"Authorization",
		},
	}))
	// ── Health ───────────────────────────────────────────────────────────────────
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// ── Public API ───────────────────────────────────────────────────────────────
	r.POST("/register", userHandler.Register)
	r.POST("/login", userHandler.Login)

	// ── Protected API ────────────────────────────────────────────────────────────
	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.GET("/users", userHandler.GetAllUsers)
		protected.GET("/users/:id", userHandler.GetUserByID)
		protected.PUT("/users/:id", userHandler.UpdateUser)
		protected.DELETE("/users/:id", userHandler.DeleteUser)
	}

	// ── Flutter web SPA ──────────────────────────────────────────────────────────
	// NoRoute is only called when no API route matches.
	// 1. Try to serve the path as a real file from the Flutter build directory.
	// 2. Otherwise serve index.html so Flutter's client-side router takes over.
	r.NoRoute(func(c *gin.Context) {
		// Prevent browsers from caching stale responses
		c.Header("Cache-Control", "no-cache, no-store, must-revalidate")
		c.Header("Pragma", "no-cache")
		c.Header("Expires", "0")

		requestedPath := c.Request.URL.Path
		filePath := filepath.Join(webDir, requestedPath)

		info, err := os.Stat(filePath)
		if err == nil && !info.IsDir() {
			c.File(filePath)
			return
		}

		c.File(filepath.Join(webDir, "index.html"))
	})

	log.Printf("server starting on :%s (flutter web from %s)", port, webDir)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
