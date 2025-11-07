# Nginx

외부 핸드폰 등 노트북에서 host붙기위한 프록시용 nginx

# serve hosts
https://서버IP:8443/chatbot

https://localhost:8443/chatbot


# WSL용 port 오픈

netsh interface portproxy add v4tov4 listenport=8443 listenaddress=0.0.0.0 connectport=8443 connectaddress=172.20.223.124