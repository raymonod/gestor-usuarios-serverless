package main

import (
	"context"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	ginadapter "github.com/awslabs/aws-lambda-go-api-proxy/gin"

	"github.com/gin-gonic/gin"

	"go-api/internal/infrastructure/database"
	"go-api/internal/infrastructure/handlers"
	"go-api/internal/infrastructure/middleware"
	"go-api/internal/infrastructure/repository"
)

var ginLambda *ginadapter.GinLambdaV2

func init() {

	db := database.NewDatabase(getEnv("DATABASE_URL", ""))

	userRepo := repository.NewUserRepository(db)
	userHandler := handlers.NewUserHandler(userRepo)

	r := gin.Default()

	// 🚨 CORS FIX GLOBAL (IMPORTANTE PARA LAMBDA + API GATEWAY)
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type,Authorization")

		// 🔥 PRE-FLIGHT REQUEST (CRÍTICO)
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(200)
			return
		}

		c.Next()
	})

	// ── ROUTES ─────────────────────────────────────

	r.POST("/register", userHandler.Register)
	r.POST("/login", userHandler.Login)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.GET("/users", userHandler.GetAllUsers)
		protected.GET("/users/:id", userHandler.GetUserByID)
		protected.PUT("/users/:id", userHandler.UpdateUser)
		protected.DELETE("/users/:id", userHandler.DeleteUser)

		protected.POST("/notifications/send", userHandler.SendNotification)
	}

	ginLambda = ginadapter.NewV2(r)
}

func main() {
	lambda.Start(func(
		ctx context.Context,
		req events.APIGatewayV2HTTPRequest,
	) (events.APIGatewayV2HTTPResponse, error) {

		return ginLambda.ProxyWithContext(ctx, req)
	})
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
