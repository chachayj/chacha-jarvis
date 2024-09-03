package application

import (
	"log"
	"go_fiber_server/src/functions/post-robot-control/domain"
)

type PostRobotControlUsecaseInterface interface {
	Execute(input_dto PostRobotControlUsecaseInputDTO) (*PostRobotControlUsecaseResultDTO, error)
}

type PostRobotControlUsecaseInputDTO struct {
	Command 		string
	RobotId 			string
}

type PostRobotControlUsecaseResultDTO struct {
	Result			string
}

type PostRobotControlUsecase struct {
	domain_service domain.PostRobotControlDomainServiceInterface
}

func NewPostRobotControlUsecase(domain_service domain.PostRobotControlDomainServiceInterface) *PostRobotControlUsecase {
	return &PostRobotControlUsecase{
		domain_service: domain_service,
	}
}

func (usecase *PostRobotControlUsecase) Execute(input_dto PostRobotControlUsecaseInputDTO) (*PostRobotControlUsecaseResultDTO, error) {
	send_input_dto := &domain.SendRobotControlInputDTO{
		Command:	input_dto.Command,
		RobotId:		input_dto.RobotId,
	}

	// ack 수신 대기 타임아웃 30초 구현필요
	
	result, nil := usecase.domain_service.SendRobotControl(*send_input_dto)

	log.Println(result)
	result_dto := &PostRobotControlUsecaseResultDTO{
		// Result: result.Result,
	}

	return result_dto, nil
}
