# chacha-jarvis-be-go

frontend/web에서 API call을 요청하는 go fiber 프레임워크를 사용한 core backend

# 아키텍처

DDD(Domain Driven Design)

기본적으로 DDD아키텍처를 도입하였고 가능한 객체지향적인 코딩을 목표로 설계했습니다.

DIP를 가능한 지키기 위해서 고심하였고 src/init에 해당 구조를 만들기 위해 init 코드들을 설계했습니다.

더 깔끔하게 설계 하고싶었으나, 현재로선 현행이 최선인것 같습니다.

간단하게 요약하자면 4 layer 형태로 각 역할별 4개의 계층이 있고
표현(presentation) -> 응용(application) -> 도메인(domain) -> 인프라(infra)

위와 같이 상위 ~ 하위로 나뉘는데
 
"하위 계층은 상위 계층을 몰라야 한다"를 목표로 설계된 아키텍처라고 보면 됩니다. (하위계층이 상위계층에 의존하지 않음)

또한 상위 계층에서도 하위계층의 실제 구현에 의존하지 않도록 interface를 활용해 추상화시켜 의존성을 적게해 DIP를 준수했습니다.

이유로는 유지보수시에 가능한 여러곳의 수정이 없도록 함이며 테스트코드 개발시 테스트를 unit별로 하기 위함입니다.


# 코딩스타일

클린코드 철학을 가능한 지켜보며 코딩 작성을 해보았습니다.

카멜 케이스로만은 가독성이 떯어지는것 같아 스네이크 케이스로 변수 선언등은 대체해서 리더블한 코드를 만들려 노력해보았습니다.

# 언어

go1.22.5

# 프레임워크

fiber v2 (LTS)

# 모듈 의존성 설치

go mod tidy

# fiber 초기 셋업

go mod init go_fiber_server

go get github.com/gofiber/fiber/v2

# 서버 run

go run main.go


# robot api call 캡처

- postman api call

![alt text](postman_api_call.png)


- mqttx mqtt spying

![alt text](mqtt_comunicate.png)