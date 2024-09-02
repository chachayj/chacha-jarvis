package main

import (
	"log"

	"github.com/joho/godotenv"

    "github.com/gofiber/fiber/v2"
)

func main() {
    // Fiber 앱 생성
    app := fiber.New()

	// .env 파일 읽기
	env_err := godotenv.Load()
	if env_err != nil {
		log.Fatalf("Error loading .env file: %v", env_err)
	}

    // 루트 라우트 설정
    app.Get("/", func(c *fiber.Ctx) error {
        return c.SendString("Hello, Fiber!")
    })

    // 서버 시작
	err := app.Listen(":3000")
	if err != nil {
		log.Fatalf("Error starting server: %v", err)
	}
}
