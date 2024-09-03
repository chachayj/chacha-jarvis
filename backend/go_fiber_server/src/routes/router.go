package routes

import (
	middleware "go_fiber_server/src/middleware"

	get_weather "go_fiber_server/src/functions/get-weather"
	post_robot_control "go_fiber_server/src/functions/post-robot-control"

	"github.com/gofiber/fiber/v2"
)

type MainRouter struct {
	GetWeatherHandler     *get_weather.GetWeatherHandler
	PostRobotControlHandler *post_robot_control.PostRobotControlHandler
}

func NewMainRouter(
	get_weather *get_weather.GetWeatherHandler,
	post_robot_control *post_robot_control.PostRobotControlHandler,
) *MainRouter {
	return &MainRouter{
		GetWeatherHandler:     			get_weather,
		PostRobotControlHandler:		post_robot_control,
	}
}

func (r *MainRouter) Setup(app *fiber.App) {
	app.Get("/weather/:city", r.GetWeatherHandler.GetWeather)
	app.Post("/robots/:robotId/control", middleware.ValidateBody[post_robot_control.PostRobotControlBody], r.PostRobotControlHandler.RequestRobotControl)
}
