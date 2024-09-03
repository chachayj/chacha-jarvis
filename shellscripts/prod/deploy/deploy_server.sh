# 변수 정의
DESTINATION_SERVER="ubuntu@ec2.ap-northeast-2.compute.amazonaws.com"
SSH_KEY="~/Desktop/work/pem/go_fiber_server.pem"
EXCLUDE_ITEMS="logs|admin_app.sock"

# scp 명령어 실행
scp -i "$SSH_KEY" -r $(ls | grep -E -v "$EXCLUDE_ITEMS") "$DESTINATION_SERVER":~/go_fiber_server
