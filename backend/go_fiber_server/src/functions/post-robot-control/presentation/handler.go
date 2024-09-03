package presentation

import (
	"log"
	"go_fiber_server/src/functions/post-robot-control/application"

	"github.com/gofiber/fiber/v2"
)

type PostRobotControlHandlerInterface interface {
	Execute(c *fiber.Ctx) error
}

type PostRobotControlHandler struct {
	usecase application.PostRobotControlUsecaseInterface
}

type PostRobotControlBody struct {
	Command 		string `json:"command" validate:"required"`
}

type PostRobotControlResponse struct {
	Result string `json:"result"`
}

func NewPostRobotControlHandler(usecase application.PostRobotControlUsecaseInterface) *PostRobotControlHandler {
	handler := &PostRobotControlHandler{
		usecase: usecase,
	}

	if handler == nil {
        log.Println("New handler is nil!")
    } else {
		log.Println("New handler is not nil!")
	}
	return handler
}

func (handler *PostRobotControlHandler) RequestRobotControl(c *fiber.Ctx) error {
	var body PostRobotControlBody
	if err := c.BodyParser(&body); err != nil {
		log.Println("RobotControlHandler BodyParser err ")
		return err
	}

	robotId := c.Params("robotId")
	log.Println("pathValues from robotId : ", robotId)

	if robotId == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "not contain robotId",
		})
	}

	usecase_input_dto := application.PostRobotControlUsecaseInputDTO{
		Command:		body.Command,
		RobotId:			robotId,
	}

	if handler == nil {
        log.Println("handler is nil!")
        return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
            "error": "Internal server error: handler is nil",
        })
    }
	RobotControl_result, err := handler.usecase.Execute(usecase_input_dto)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	if RobotControl_result == nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Robot Control failed",
		})
	}

	resp := PostRobotControlResponse{
		Result: "Done",
	}
	return c.JSON(resp)
}
