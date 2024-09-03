package dynamodb

import (
	open_weather_map_manager "go_fiber_server/src/common/domain/open_weather_map_manager"
	robot_manager "go_fiber_server/src/common/domain/robot_manager"

	http_caller "go_fiber_server/src/common/infra/http_caller"
	mqtt_client "go_fiber_server/src/common/infra/mqtt_client"
)

type Domains struct {
	Open_weather_map_manager open_weather_map_manager.OpenWeatherMapManagerInterface
	Robot_manager            robot_manager.RobotManagerInterface
}

func InitializeDomains(
	http_caller http_caller.HttpCallerInterface,
	mqtt_client mqtt_client.MqttBrokerInterface,
) *Domains {
	// Initialize Domains
	return &Domains{
		Open_weather_map_manager: open_weather_map_manager.NewOpenWeatherMapManager(http_caller),
		Robot_manager:            robot_manager.NewRobotManager(mqtt_client),
	}
}
