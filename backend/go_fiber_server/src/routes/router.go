package routes

import (
	middleware "go_fiber_server/src/middleware"
	post_robot_control "go_fiber_server/src/functions/post-robot-control"

	"github.com/gofiber/fiber/v2"
)

type MainRouter struct {
	PostRobotControlHandler *post_robot_control.PostRobotControlHandler
}

func NewMainRouter(
	post_robot_control *post_robot_control.PostRobotControlHandler,
) *MainRouter {
	return &MainRouter{
		PostRobotControlHandler:		post_robot_control,
	}
}

func (r *MainRouter) Setup(app *fiber.App) {
	app.Post("/robots/:robotId/control", middleware.ValidateBody[post_robot_control.PostRobotControlBody], r.PostRobotControlHandler.RequestRobotControl)
}
