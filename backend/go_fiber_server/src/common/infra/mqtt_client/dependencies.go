package mqtt_client

func InitializeMqttClient() *MqttBroker {
	// Initialize MqttClient
	return NewMqttBroker()
}
