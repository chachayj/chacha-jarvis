package init

import (
	domains "go_fiber_server/src/common/domain"
	
	http_caller "go_fiber_server/src/common/infra/http_caller"
	mqtt_client "go_fiber_server/src/common/infra/mqtt_client"

	post_robot_control "go_fiber_server/src/functions/post-robot-control"
	get_weather "go_fiber_server/src/functions/get-weather"
)

type Dependencies struct {
	get_weather_handler      				*get_weather.GetWeatherHandler
	post_robot_control_handler 				*post_robot_control.PostRobotControlHandler
}

func InitializeDependencies() *Dependencies {
	inited_http_caller := http_caller.InitializeHttpCaller()
	inited_mqtt_client := mqtt_client.InitializeMqttClient()

	inited_domains := domains.InitializeDomains(
		inited_http_caller,
		inited_mqtt_client,
	)

	return &Dependencies{
		get_weather_handler: get_weather.InitializeHandler(
			inited_domains.Open_weather_map_manager,
		),
		post_robot_control_handler: post_robot_control.InitializeHandler(
			inited_domains.Robot_manager,
		),
	}
}
