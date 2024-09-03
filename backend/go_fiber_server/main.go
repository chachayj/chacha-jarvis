package main

import (
	"log"
	initModules "go_fiber_server/src/init"

	"github.com/joho/godotenv"

    "github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
)

func main() {
    // Fiber 앱 생성
    app := fiber.New()

	// .env 파일 읽기
	env_err := godotenv.Load()
	if env_err != nil {
		log.Fatalf("Error loading .env file: %v", env_err)
	}

	// CORS 미들웨어 추가
	app.Use(cors.New(cors.Config{
		AllowOrigins:  "*",
		AllowMethods:  "GET,POST,OPTIONS",
		AllowHeaders:  "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range",
		ExposeHeaders: "Content-Length,Content-Range",
	}))

	// Initialize dependencies and setup routes
	initModules.InitialModules(app)

    // 서버 시작
	err := app.Listen(":3000")
	if err != nil {
		log.Fatalf("Error starting server: %v", err)
	}
}
