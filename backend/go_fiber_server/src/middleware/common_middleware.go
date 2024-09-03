package middleware

import (
	"github.com/gofiber/fiber/v2"
)

type CommonMiddleware struct {
	logger Logger
}

func NewCommonMiddleware(logger Logger) *CommonMiddleware {
	return &CommonMiddleware{
		logger: logger,
	}
}

func (m *CommonMiddleware) Setup(app *fiber.App) {
	if m.logger == nil {
		m.logger = &DefaultLogger{}
	}
	app.Use(m.logger.Log)
}
