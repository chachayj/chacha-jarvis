# chacha-jarvis
Ai 비서를 이용한 전구, 모터, 센서 등 라즈베리 디바이스들을 제어하는 IoT 시스템 프로젝트

# 프로젝트 구조

FrontEnd, BackEnd, Embeded 3개의 영역을 폴더별로 정리하였고

하위 요소들별 폴더를 만들은 mono repo 형태이다.



# 구상중인 디렉토리 구조 (안)
```
Chacha-jarvis(monorepo)/
├── backend/
│   ├── flask_server/
│   │   └── app.py
│   └── go_fiber_server/
│       └── main.go
├── embeded/
│   ├── ros/
│   │   └── rospy_app.py
└── frontend/
    ├── web/
    │   ├── reactjs/
    │   │   ├── public/
    │   │   │   └── index.html
    │   │   ├── src/
    │   │   │   ├── components/
    │   │   │   ├── hooks/
    │   │   │   ├── pages/
    │   │   │   └── styles/
    │   │   └── package.json
    │   ├── vuejs/
    │   │   ├── public/
    │   │   │   └── index.html
    │   │   ├── src/
    │   │   │   ├── assets/
    │   │   │   ├── components/
    │   │   │   ├── router/
    │   │   │   └── views/
    │   │   └── package.json
    │   └── nextjs/
    │       ├── public/
    │       │   └── images/
    │       ├── src/
    │       │   ├── components/
    │       │   ├── pages/
    │       │   └── styles/
    │       └── package.json
    ├── ios/
    │   ├── src/
    │   │   ├── AppDelegate.swift
    │   │   └── ViewController.swift
    │   └── Info.plist
    └── android/
        ├── src/
        │   ├── MainActivity.java
        │   └── MainApplication.java
        └── AndroidManifest.xml
```