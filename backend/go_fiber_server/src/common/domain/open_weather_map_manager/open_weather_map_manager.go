package open_weather_map_manager

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	http_caller "go_fiber_server/src/common/infra/http_caller"
)

type OpenWeatherMapManagerInterface interface {
	SendToOpenWeatherMap(input_dto SendToOpenWeatherMapInputDTO) (*WeatherData, error)
}

type WeatherData struct {
	Main       MainData        `json:"main"`
	Visibility int             `json:"visibility"`
	Wind       WindData        `json:"wind"`
	Clouds     CloudsData      `json:"clouds"`
	Dt         float64         `json:"dt"`
	Id         float64         `json:"id"`
	Cod        int             `json:"cod"`
	Coord      CoordData       `json:"coord"`
	Weather    []WeatherDetail `json:"weather"`
	Base       string          `json:"base"`
	Sys        SysData         `json:"sys"`
	Timezone   int             `json:"timezone"`
	Name       string          `json:"name"`
}

type MainData struct {
	FeelsLike float64 `json:"feels_like"`
	Humidity  int     `json:"humidity"`
	Pressure  int     `json:"pressure"`
	Temp      float64 `json:"temp"`
	TempMax   float64 `json:"temp_max"`
	TempMin   float64 `json:"temp_min"`
}

type WindData struct {
	Deg   int     `json:"deg"`
	Speed float64 `json:"speed"`
}

type CloudsData struct {
	All int `json:"all"`
}

type CoordData struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

type WeatherDetail struct {
	Description string `json:"description"`
	Icon        string `json:"icon"`
	Id          int    `json:"id"`
	Main        string `json:"main"`
}

type SysData struct {
	Country string  `json:"country"`
	Id      int     `json:"id"`
	Sunrise float64 `json:"sunrise"`
	Sunset  float64 `json:"sunset"`
	Type    int     `json:"type"`
}

type SendToOpenWeatherMapInputDTO struct {
	City string
}

type OpenWeatherMapManager struct {
	Http_caller http_caller.HttpCallerInterface
}

func NewOpenWeatherMapManager(
	http_caller http_caller.HttpCallerInterface,
) *OpenWeatherMapManager {
	return &OpenWeatherMapManager{
		Http_caller: http_caller,
	}
}

// func (domain_service *OpenWeatherMapManager) SendToOpenWeatherMap(input_dto SendToOpenWeatherMapInputDTO) (*SendToLLMFAQResultDTO, error) {
func (domain_service *OpenWeatherMapManager) SendToOpenWeatherMap(input_dto SendToOpenWeatherMapInputDTO) (*WeatherData, error) {
	// API 엔드포인트 설정
	apiKey := os.Getenv("OPEN_WEATHER_MAP_KEY")
	url := fmt.Sprintf("http://api.openweathermap.org/data/2.5/weather?q=%s&appid=%s", input_dto.City, apiKey)

	// API 호출
	response, err := domain_service.Http_caller.CallGetByUrl(url)
	if err != nil {
		fmt.Println("API 호출 중 오류 발생:", err)
		return nil, err
	}
	defer response.Body.Close()
	// 응답 바디 읽기
	body, err := io.ReadAll(response.Body)
	if err != nil {
		fmt.Println("응답 바디 읽기 중 오류 발생:", err)
		return nil, err
	}

	// JSON 디코딩하여 날씨 정보 가져오기
	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		fmt.Println("JSON 디코딩 중 오류 발생:", err)
		return nil, err
	}

	// cod 값 확인
	codValue, exists := data["cod"]
	if !exists {
		fmt.Println("cod field does not exist in the response")
		return nil, fmt.Errorf("cod field does not exist in the response")
	}

	// cod 값이 float64로 캐스팅 가능한지 확인
	codFloat, ok := codValue.(float64)
	if !ok {
		fmt.Println("cod field is not a valid float64")
		return nil, fmt.Errorf("cod field is not a valid float64")
	}
	var weather_dto WeatherData

	// cod 값이 200인 경우에만 처리
	if codFloat == 200 {
		// 맵 데이터를 구조체로 변환
		weatherData, err := mapToWeatherData(data)
		if err != nil {
			// Handle the error
			fmt.Println("mapToWeatherData Error:", err)
			return nil, err
		}
		weather_dto = weatherData
		// 구조체 출력
		fmt.Printf("%+v\n", weatherData)
	} else {
		message, ok := data["message"]
		if !ok {
			fmt.Println("message field is not a valid")
			return nil, fmt.Errorf("message field is not a valid")
		} else {
			return nil, fmt.Errorf("status code %f, message : %s", codFloat, message)
		}
	}

	return &weather_dto, nil
}

// mapToWeatherData 함수는 맵 데이터를 WeatherData 구조체로 변환합니다.
func mapToWeatherData(data map[string]interface{}) (WeatherData, error) {
	weatherData := WeatherData{}

	main, ok := data["main"].(map[string]interface{})
	if !ok {
		return weatherData, fmt.Errorf("main field is not a valid map")
	}
	weatherData.Main = MainData{
		FeelsLike: math.Round((main["feels_like"].(float64)-273.15)*100) / 100,
		Humidity:  int(main["humidity"].(float64)),
		Pressure:  int(main["pressure"].(float64)),
		Temp:      math.Round((main["temp"].(float64)-273.15)*100) / 100,
		TempMax:   main["temp_max"].(float64),
		TempMin:   main["temp_min"].(float64),
	}

	visibility, ok := data["visibility"].(float64)
	if !ok {
		return weatherData, fmt.Errorf("visibility field is not a valid float64")
	}
	weatherData.Visibility = int(visibility)

	wind, ok := data["wind"].(map[string]interface{})
	if !ok {
		return weatherData, fmt.Errorf("wind field is not a valid map")
	}
	weatherData.Wind = WindData{
		Deg:   int(wind["deg"].(float64)),
		Speed: wind["speed"].(float64),
	}

	clouds, ok := data["clouds"].(map[string]interface{})
	if !ok {
		return weatherData, fmt.Errorf("clouds field is not a valid map")
	}
	weatherData.Clouds = CloudsData{
		All: int(clouds["all"].(float64)),
	}

	weatherData.Name = data["name"].(string)

	// weather 데이터 처리
	weatherArray, ok := data["weather"].([]interface{})
	if ok && len(weatherArray) > 0 {
		// 첫 번째 날씨 상태만 고려
		weather := weatherArray[0].(map[string]interface{})
		weatherDetail := WeatherDetail{
			Description: weather["description"].(string),
			Icon:        weather["icon"].(string),
			Id:          int(weather["id"].(float64)),
			Main:        weather["main"].(string),
		}
		weatherData.Weather = []WeatherDetail{weatherDetail}
	} else {
		weatherData.Weather = []WeatherDetail{}
	}

	return weatherData, nil
}
