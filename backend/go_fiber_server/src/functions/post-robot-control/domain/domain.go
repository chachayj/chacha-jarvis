package domain

import (
	"go_fiber_server/src/common/domain/robot_manager"
)

type PostRobotControlDomainServiceInterface interface {
	SendRobotControl(input_dto SendRobotControlInputDTO) (string, error)
}

type SendRobotControlInputDTO struct {
	Command 		string
	RobotId 			string
}

type SendRobotControlResultDTO struct {
	Result			string
}

type PostRobotControlDomainService struct {
	Robot_manager       robot_manager.RobotManagerInterface
}

func NewPostRobotControlDomainService(
	robot_manager robot_manager.RobotManagerInterface,
) *PostRobotControlDomainService {
	return &PostRobotControlDomainService{
		Robot_manager:       robot_manager,
	}
}

func (domain_service *PostRobotControlDomainService) SendRobotControl(input_dto SendRobotControlInputDTO) (string, error) {
	send_input_dto := &robot_manager.SendRobotControlCommandInputDTO{
		Command:	input_dto.Command,
		RobotId:      input_dto.RobotId,
	}

	result, err := domain_service.Robot_manager.SendRobotControlCommand(*send_input_dto)
	if err != nil {
		return "nil", err
	}

	return result, nil
}