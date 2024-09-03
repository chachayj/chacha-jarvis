package dynamodb

import (
	robot_manager "go_fiber_server/src/common/domain/robot_manager"

	mqtt_client "go_fiber_server/src/common/infra/mqtt_client"
)

type Domains struct {
	Robot_manager            robot_manager.RobotManagerInterface
}

func InitializeDomains(
	mqtt_client mqtt_client.MqttBrokerInterface,
) *Domains {
	// Initialize Domains
	return &Domains{
		Robot_manager:            robot_manager.NewRobotManager(mqtt_client),
	}
}
