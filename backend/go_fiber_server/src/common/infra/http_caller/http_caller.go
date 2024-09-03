package http_caller

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/textproto"
)

type HttpCallerInterface interface {
	CallGetByUrl(url string) (*http.Response, error)
	CallPostWithBodyJson(url string, body map[string]string) (*http.Response, error)
	SetHeader(header map[string]string, key, value string)
	CallGetByUrlWithHeader(url string, header map[string]string) (*http.Response, error)
}

type HttpCaller struct {
	client *http.Client // 클라이언트 필드 추가
}

func NewHttpCaller() *HttpCaller {
	return &HttpCaller{
		client: &http.Client{}, // 클라이언트 초기화
	}
}

func (httpCaller *HttpCaller) CallGetByUrl(url string) (*http.Response, error) {
	return httpCaller.client.Get(url) // 클라이언트 필드로 요청 보내기
}

func (httpCaller *HttpCaller) CallPostWithBodyJson(url string, body map[string]string) (*http.Response, error) {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	return httpCaller.client.Post(url, "application/json", bytes.NewBuffer(jsonBody))
}

func (httpCaller *HttpCaller) SetHeader(header map[string]string, key, value string) {
	// 키를 소문자로 표준화합니다.
	canonicalKey := textproto.CanonicalMIMEHeaderKey(key)

	// 맵에 키와 값을 설정합니다.
	header[canonicalKey] = value
}

func (httpCaller *HttpCaller) CallGetByUrlWithHeader(url string, header map[string]string) (*http.Response, error) {
	// GET 요청 보내기
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		fmt.Println("Error creating request:", err)
		return nil, err
	}

	// 헤더 추가
	for key, value := range header {
		req.Header.Add(key, value)
	}

	// 요청 보내기
	resp, err := httpCaller.client.Do(req)
	if err != nil {
		fmt.Println("Error sending request:", err)
		return nil, err
	}
	fmt.Println("Response:", resp)
	return resp, nil
}
