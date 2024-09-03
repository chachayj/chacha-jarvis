package application

import (
	"log"
	"go_fiber_server/src/functions/get-weather/domain"
)

type GetWeatherUsecaseInterface interface {
	Execute(city string) (*GetWeatherResultDTO, error)
}

type GetWeatherResultDTO = domain.GetWeatherResultDTO

type GetWeatherUsecase struct {
	domain_service domain.GetWeatherDomainServiceInterface
}

func NewGetWeatherUsecase(domain_service domain.GetWeatherDomainServiceInterface) *GetWeatherUsecase {
	return &GetWeatherUsecase{
		domain_service: domain_service,
	}
}

func (usecase *GetWeatherUsecase) Execute(city string) (*GetWeatherResultDTO, error) {
	log.Println("GetWeatherUsecase Execute : ", city)

	get_weather_input_dto := &domain.GetWeatherInputDTO{
		City: city,
	}

	result, err := usecase.domain_service.GetWeather(*get_weather_input_dto)
	if err != nil {
		log.Println("GetWeather error:", err)
		return nil, err
	}

	return result, err
}
