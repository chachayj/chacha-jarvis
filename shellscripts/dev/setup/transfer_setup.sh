# 변수 정의
DESTINATION_SERVER="ubuntu@ec2.ap-northeast-2.compute.amazonaws.com"
SSH_KEY="~/Desktop/work/pem/go_fiber_server.pem"
SOURCE_DIR="shellscripts/prod/setup/"
DESTINATION_DIR="~/setup"

# scp 명령어 실행
scp -i "$SSH_KEY" -r "$SOURCE_DIR"* "$DESTINATION_SERVER":"$DESTINATION_DIR"
