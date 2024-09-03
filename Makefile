# 변수 정의
PROD_SERVER = ubuntu@ec2.ap-northeast-2.compute.amazonaws.com

SSH_KEY_PATH = ~/Desktop/work/pem/go_fiber_server.pem
PROD_SOURCE_DIR = shellscripts/prod
DESTINATION_DIR = ~/setup
BACK_END_SERVICE_NAME = go_fiber_server

# 경고 메시지
warnning:
	@echo "Do not just type the make command !!"

# github 코드 개발 브랜치를 프로덕션 브랜치로 병합
git_merge_force_dev_to_prod:
	@echo "before use this command, you must tag the semantic version like '1.5.0' "
	@echo "ex) git tag 1.5.0"
	@echo
	git checkout prod
	git merge --strategy=recursive -X theirs dev
	git push --tags
	git push

connect_server_dev:
	sh shellscripts/dev/connect_server/connect_server.sh

connect_server_prod:
	sh shellscripts/prod/connect_server/connect_server.sh

# 프로덕션 서버에 배포
deploy_prod_go_fiber_server:
	@echo "deploy go_fiber_server"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo rm -r ~/$(BACK_END_SERVICE_NAME)/src"
	sh $(PROD_SOURCE_DIR)/deploy/deploy_server.sh
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "cd go_fiber_server && /usr/local/go/bin/go build -o go_fiber_server ~/go_fiber_server/main.go"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl restart $(BACK_END_SERVICE_NAME).service"
    
# 프로덕션 서버에서 서비스 fetch하기
fetch_prod_services:
	@echo "fetch_services"
	sh $(PROD_SOURCE_DIR)/setup/transfer_setup.sh
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "ls -al | grep setup"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo cp setup/systemservices/$(BACK_END_SERVICE_NAME).service /usr/lib/systemd/system/"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl daemon-reload"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl restart $(BACK_END_SERVICE_NAME).service"

# 프로덕션 서버의 robot_system_be_core_server 서비스 확인
check_prod_robot_system_be_core_server:
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl status $(BACK_END_SERVICE_NAME).service"

# 프로덕션 서버 설정
setup_prod_robot_system_be_core_server:
	@echo "setup_services"
	sh $(PROD_SOURCE_DIR)/setup/transfer_setup.sh
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "ls -al | grep setup"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo cp setup/systemservices/$(BACK_END_SERVICE_NAME).service /usr/lib/systemd/system/"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl daemon-reload"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl enable $(BACK_END_SERVICE_NAME).service"
	ssh -i $(SSH_KEY_PATH) $(PROD_SERVER) "sudo systemctl start $(BACK_END_SERVICE_NAME).service"
