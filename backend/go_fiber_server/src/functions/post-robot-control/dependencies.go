package post_robot_control

import (
	"go_fiber_server/src/functions/post-robot-control/application"
	"go_fiber_server/src/functions/post-robot-control/domain"
	"go_fiber_server/src/functions/post-robot-control/presentation"

	robot_manager "go_fiber_server/src/common/domain/robot_manager"
)

func InitializeHandler(
	robot_manager robot_manager.RobotManagerInterface,
) *presentation.PostRobotControlHandler {
	// Initialize dependencies
	post_robot_control_domain := domain.NewPostRobotControlDomainService(robot_manager)
	post_robot_control_usecase := application.NewPostRobotControlUsecase(post_robot_control_domain)
	post_robot_control_handler := presentation.NewPostRobotControlHandler(post_robot_control_usecase)
	return post_robot_control_handler
}

type PostRobotControlHandler = presentation.PostRobotControlHandler
type PostRobotControlBody = presentation.PostRobotControlBody