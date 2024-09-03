package mqtt_client

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	MQTT "github.com/eclipse/paho.mqtt.golang"
)




type MqttBrokerInterface interface {
	PublishRobotControlCommand(payload map[string]string, robotId string) (string, error)
}

type MqttBroker struct {
	client MQTT.Client
}

func NewMqttBroker() *MqttBroker {
	// MQTT 브로커 정보
	var mqttBrokerAddress = os.Getenv("MQTT_BROKER_ADDRESS")
	var mqttPort = os.Getenv("MQTT_PORT")

	// TLS 인증서 파일 경로
	var caCertPath = os.Getenv("CA_CERT")
	var clientCertPath = os.Getenv("CLIENT_CERT")
	var clientKeyPath = os.Getenv("CLIENT_KEY")

	// 현재 작업 디렉토리 가져오기
	basePath, err := os.Getwd()
	if err != nil {
		fmt.Println("Error getting current working directory:", err)
	}

	// 인증서 경로를 현재 작업 디렉토리를 기준으로 설정
	caCertFile := filepath.Join(basePath, caCertPath)
	clientCertFile := filepath.Join(basePath, clientCertPath)
	clientKeyFile := filepath.Join(basePath, clientKeyPath)

	opts := MQTT.NewClientOptions()
	opts.AddBroker(fmt.Sprintf("ssl://%s:%s", mqttBrokerAddress, mqttPort))
	opts.SetClientID("go-mqtt-client")
	opts.SetPingTimeout(time.Duration(1) * time.Second)
	opts.SetKeepAlive(2 * time.Second)

	// CA 인증서 로드
	caCertData, err := os.ReadFile(caCertFile)
	if err != nil {
		fmt.Println("Failed to load CA certificate:", err)
	}
	certPool := x509.NewCertPool()
	certPool.AppendCertsFromPEM(caCertData)

	// 클라이언트 인증서 및 키 로드
	clientCert, err := tls.LoadX509KeyPair(clientCertFile, clientKeyFile)
	if err != nil {
		fmt.Println("Failed to load client certificates:", err)
	}

	tlsConfig := &tls.Config{
		RootCAs:      certPool,
		Certificates: []tls.Certificate{clientCert},
		MinVersion:   tls.VersionTLS12,
	}

	opts.SetTLSConfig(tlsConfig)

	// MQTT 클라이언트 생성
	client := MQTT.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		fmt.Println(token.Error())
	}

	opts.SetConnectionLostHandler(func(client MQTT.Client, err error) {
		fmt.Printf("Connection lost: %v\n", err)
		for !client.IsConnected() {
			fmt.Println("Attempting to reconnect...")
			if token := client.Connect(); token.Wait() && token.Error() != nil {
				fmt.Printf("Error reconnecting: %v\n", token.Error())
				time.Sleep(3 * time.Second)
			}
		}
		fmt.Println("Reconnected successfully")
	})

	return &MqttBroker{
		client: client,
	}
}

func (mqtt_broker *MqttBroker) PublishRobotControlCommand(payload map[string]string, robotId string) (string, error) {
	json_payload, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	fmt.Println("mqtt_broker.client.IsConnected() : ", mqtt_broker.client.IsConnected())
	if !mqtt_broker.client.IsConnected() {
		fmt.Println("Attempting to reconnect...")
		if token := mqtt_broker.client.Connect(); token.Wait() && token.Error() != nil {
			fmt.Printf("Error reconnecting: %v\n", token.Error())
			return "", fmt.Errorf("error reconnecting: %v", token.Error())
		}
		fmt.Println("Reconnected successfully")
	}

	topic := "/Robot_Control_Command/" + robotId
	fmt.Println(topic)
	token := mqtt_broker.client.Publish(topic, 0, false, json_payload)

	if !token.WaitTimeout(5 * time.Second) {
		fmt.Println("Message published token.WaitTimeout() : ")
		return "", fmt.Errorf("message publishing timed out")
	}

	if token.Error() != nil {
		fmt.Println("Message published token.Error() : ", token.Error())
		return "", fmt.Errorf("error publishing message: %v", token.Error())
	}

	fmt.Println("Message published successfully")
	return "", nil
}
