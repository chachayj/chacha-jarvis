package middleware

import (
	"log"
	"time"

	"github.com/gofiber/fiber/v2"
)

type Logger interface {
	Log(c *fiber.Ctx) error
}

type DefaultLogger struct{}

func (l *DefaultLogger) Log(c *fiber.Ctx) error {
	start := time.Now()
	log.Printf("Request: %s - %s - %s - %v", c.Method(), c.Body(), c.Path(), time.Since(start))
	return c.Next()
}
