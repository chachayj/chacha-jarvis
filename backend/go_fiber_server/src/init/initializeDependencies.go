package init

import (
	domains "go_fiber_server/src/common/domain"
	mqtt_client "go_fiber_server/src/common/infra/mqtt_client"
	post_robot_control "go_fiber_server/src/functions/post-robot-control"
)

type Dependencies struct {
	post_robot_control_handler 				*post_robot_control.PostRobotControlHandler
}

func InitializeDependencies() *Dependencies {

	inited_mqtt_client := mqtt_client.InitializeMqttClient()

	inited_domains := domains.InitializeDomains(inited_mqtt_client)

	return &Dependencies{
		post_robot_control_handler: post_robot_control.InitializeHandler(
			inited_domains.Robot_manager,
		),
	}
}
