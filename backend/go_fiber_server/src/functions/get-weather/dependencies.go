package get_weather

import (
	"go_fiber_server/src/functions/get-weather/application"
	"go_fiber_server/src/functions/get-weather/domain"
	"go_fiber_server/src/functions/get-weather/presentation"

	open_weather_map_manager "go_fiber_server/src/common/domain/open_weather_map_manager"
)

func InitializeHandler(
	open_weather_map_manager open_weather_map_manager.OpenWeatherMapManagerInterface,
) *presentation.GetWeatherHandler {

	// Initialize dependencies
	get_weather_domain := domain.NewGetWeatherDomainService(open_weather_map_manager)
	get_weather_usecase := application.NewGetWeatherUsecase(get_weather_domain)
	get_weather_handler := presentation.NewGetWeatherHandler(get_weather_usecase)

	return get_weather_handler
}

type GetWeatherHandler = presentation.GetWeatherHandler
