package main

import (
    "github.com/gofiber/fiber/v2"
)

func main() {
    // Fiber 앱 생성
    app := fiber.New()

    // 루트 라우트 설정
    app.Get("/", func(c *fiber.Ctx) error {
        return c.SendString("Hello, Fiber!")
    })

    // 서버 시작
    app.Listen(":3000")
}