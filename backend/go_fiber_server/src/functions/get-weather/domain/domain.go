package domain

import (
	open_weather_map_manager "go_fiber_server/src/common/domain/open_weather_map_manager"
)

type GetWeatherDomainServiceInterface interface {
	GetWeather(input_dto GetWeatherInputDTO) (*GetWeatherResultDTO, error)
}

type GetWeatherInputDTO struct {
	City string
}

type GetWeatherResultDTO = open_weather_map_manager.WeatherData

type GetWeatherDomainService struct {
	Open_weather_map_manager open_weather_map_manager.OpenWeatherMapManagerInterface
}

func NewGetWeatherDomainService(
	open_weather_map_manager open_weather_map_manager.OpenWeatherMapManagerInterface,
) *GetWeatherDomainService {
	return &GetWeatherDomainService{
		Open_weather_map_manager: open_weather_map_manager,
	}
}

func (domain_service *GetWeatherDomainService) GetWeather(input_dto GetWeatherInputDTO) (*GetWeatherResultDTO, error) {
	send_to_llm_faq_input_dto := &open_weather_map_manager.SendToOpenWeatherMapInputDTO{
		City: input_dto.City,
	}

	result, err := domain_service.Open_weather_map_manager.SendToOpenWeatherMap(*send_to_llm_faq_input_dto)
	if err != nil {
		return nil, err
	}

	return result, nil
}
