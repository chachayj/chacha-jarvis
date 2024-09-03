package presentation

import (
	"go_fiber_server/src/functions/get-weather/application"

	"github.com/gofiber/fiber/v2"
)

type GetWeatherHandlerInterface interface {
	Execute(c *fiber.Ctx) error
}

type GetWeatherResponse = application.GetWeatherResultDTO

type GetWeatherHandler struct {
	get_weather_usecase application.GetWeatherUsecaseInterface
}

func NewGetWeatherHandler(user_history_usecage application.GetWeatherUsecaseInterface) *GetWeatherHandler {
	return &GetWeatherHandler{
		get_weather_usecase: user_history_usecage,
	}
}

func (handler *GetWeatherHandler) GetWeather(c *fiber.Ctx) error {
	city := c.Params("city")

	weather, err := handler.get_weather_usecase.Execute(city)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	// resp := GetWeatherResponse{
	// 	Main:       MainData(weather.Main),
	// 	Visibility: weather.Visibility,
	// 	Wind:       WindData(weather.Wind),
	// 	Clouds:     CloudsData(weather.Clouds),
	// 	Dt:         weather.Dt,
	// 	Id:         weather.Id,
	// 	Coord:      CoordData(weather.Coord),
	// 	Weather:    make([]WeatherDetail, len(weather.Weather)), // Weather 필드 초기화
	// 	Base:       weather.Base,
	// 	Timezone:   weather.Timezone,
	// 	Name:       weather.Name,
	// }
	return c.JSON(weather)
}
