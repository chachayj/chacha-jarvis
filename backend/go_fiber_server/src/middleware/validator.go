package middleware

import (
	"log"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
)

var validate = validator.New()

// 제네릭을 사용하려면 메서드가 되면 안된다.
func ValidateBody[T any](c *fiber.Ctx) error {
	var body T
	if err := c.BodyParser(&body); err != nil {
		log.Println("ValidateBody BodyParser err ")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ValidateBody BodyParser failed, " + err.Error(),
		})
	}

	// Validate request body
	if err := validate.Struct(body); err != nil {
		log.Println("ValidateBody validate err ")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ValidateBody validate failed, " + err.Error(),
		})
	}

	// Set validated body to locals
	c.Locals("body", body)
	return c.Next()
}

func ValidateQuery[T any](c *fiber.Ctx) error {
	var query T
	if err := c.QueryParser(&query); err != nil {
		log.Println("ValidateQuery QueryParser err ")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ValidateQuery QueryParser failed, " + err.Error(),
		})
	}

	// Validate query parameters
	if err := validate.Struct(query); err != nil {
		log.Println("ValidateQuery validate err ")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ValidateQuery validate failed, " + err.Error(),
		})
	}

	// Set validated query parameters to locals
	c.Locals("query", query)
	return c.Next()
}
