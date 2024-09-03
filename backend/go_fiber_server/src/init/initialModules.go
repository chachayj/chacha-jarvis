package init

import (
	"go_fiber_server/src/middleware"
	"go_fiber_server/src/routes"

	"github.com/gofiber/fiber/v2"
)

func InitialModules(app *fiber.App) {
	// Setup middleware
	middlewareManager := middleware.CommonMiddleware{}
	middlewareManager.Setup(app)

	// Initialize dependencies
	dependencies := InitializeDependencies()

	// Setup routes
	routerManager := routes.NewMainRouter(
		dependencies.post_robot_control_handler,
	)
	routerManager.Setup(app)
}
