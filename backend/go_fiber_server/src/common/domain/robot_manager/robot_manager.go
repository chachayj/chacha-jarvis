package robot_manager

import (
	mqtt_client "go_fiber_server/src/common/infra/mqtt_client"
)

type RobotManagerInterface interface {
	SendRobotControlCommand(input_dto SendRobotControlCommandInputDTO) (string, error)
}

type SendRobotControlCommandInputDTO struct {
	Command	string
	RobotId	string
}

type SendRobotControlCommandResultDTO struct {
	Result	string
}

type RobotManager struct {
	mqtt_client mqtt_client.MqttBrokerInterface
}

func NewRobotManager(
	mqtt_client mqtt_client.MqttBrokerInterface,
) *RobotManager {
	return &RobotManager{
		mqtt_client: mqtt_client,
	}
}

func (domain_service *RobotManager) SendRobotControlCommand(input_dto SendRobotControlCommandInputDTO) (string, error) {
	payload := map[string]string{
		"command":		input_dto.Command,
	}
	domain_service.mqtt_client.PublishRobotControlCommand(payload, input_dto.RobotId)

	return "result_dto", nil
}