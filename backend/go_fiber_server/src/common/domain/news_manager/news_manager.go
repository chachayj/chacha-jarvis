package news_manager

import (
	"encoding/json"
	"fmt"
	"io"
	"log"

	http_caller "go_fiber_server/src/common/infra/http_caller"
)

// 요청 URL
// 요청 URL	반환 형식
// https://openapi.naver.com/v1/search/news.xml	XML
// https://openapi.naver.com/v1/search/news.json  JSON

// 프로토콜
// HTTPS

// HTTP 메서드
// GET

// 파라미터
// 파라미터를 쿼리 스트링 형식으로 전달합니다.

// 파라미터	타입	필수 여부	설명
// query	String	Y	검색어. UTF-8로 인코딩되어야 합니다.
// display	Integer	N	한 번에 표시할 검색 결과 개수(기본값: 10, 최댓값: 100)
// start	Integer	N	검색 시작 위치(기본값: 1, 최댓값: 1000)
// sort	String	N	검색 결과 정렬 방법
// - sim: 정확도순으로 내림차순 정렬(기본값)
// - date: 날짜순으로 내림차순 정렬

// 참고 사항
// API를 요청할 때 다음 예와 같이 HTTP 요청 헤더에 클라이언트 아이디와 클라이언트 시크릿을 추가해야 합니다.

// > GET /v1/search/news.xml?query=%EC%A3%BC%EC%8B%9D&display=10&start=1&sort=sim HTTP/1.1
// > Host: openapi.naver.com
// > User-Agent: curl/7.49.1
// > Accept: */*
// > X-Naver-Client-Id: {애플리케이션 등록 시 발급받은 클라이언트 아이디 값}
// > X-Naver-Client-Secret: {애플리케이션 등록 시 발급받은 클라이언트 시크릿 값}
// >
// 요청 예
// curl "https://openapi.naver.com/v1/search/news.xml?query=%EC%A3%BC%EC%8B%9D&display=10&start=1&sort=sim" \
//     -H "X-Naver-Client-Id: {애플리케이션 등록 시 발급받은 클라이언트 아이디 값}" \
//     -H "X-Naver-Client-Secret: {애플리케이션 등록 시 발급받은 클라이언트 시크릿 값}" -v

// 응답
//응답에 성공하면 결괏값을 XML 형식 또는 JSON 형식으로 반환합니다. XML 형식의 결괏값은 다음과 같습니다.

// 요소	타입	설명
// rss	-	RSS 컨테이너. RSS 리더기를 사용해 검색 결과를 확인할 수 있습니다.
// rss/channel	-	검색 결과를 포함하는 컨테이너. channel 요소의 하위 요소인 title, link, description은 RSS에서 사용하는 정보이며, 검색 결과와는 상관이 없습니다.
// rss/channel/lastBuildDate	dateTime	검색 결과를 생성한 시간
// rss/channel/total	Integer	총 검색 결과 개수
// rss/channel/start	Integer	검색 시작 위치
// rss/channel/display	Integer	한 번에 표시할 검색 결과 개수
// rss/channel/item	-	개별 검색 결과. JSON 형식의 결괏값에서는 items 속성의 JSON 배열로 개별 검색 결과를 반환합니다.
// rss/channel/item/title	String	뉴스 기사의 제목. 제목에서 검색어와 일치하는 부분은 <b> 태그로 감싸져 있습니다.
// rss/channel/item/originallink	String	뉴스 기사 원문의 URL
// rss/channel/item/link	String	뉴스 기사의 네이버 뉴스 URL. 네이버에 제공되지 않은 기사라면 기사 원문의 URL을 반환합니다.
// rss/channel/item/description	String	뉴스 기사의 내용을 요약한 패시지 정보. 패시지 정보에서 검색어와 일치하는 부분은 <b> 태그로 감싸져 있습니다.
// rss/channel/item/pubDate	dateTime	뉴스 기사가 네이버에 제공된 시간. 네이버에 제공되지 않은 기사라면 기사 원문이 제공된 시간을 반환합니다.

type NewsManagerInterface interface {
	SendToNaverNews(input_dto SendToNaverNewsInputDTO) (*NewsData, error)
}

type NewsData struct {
	LastBuildDate string `json:"lastBuildDate"`
	Total         int    `json:"total"`
	Start         int    `json:"start"`
	Display       int    `json:"display"`
	Items         []struct {
		Title        string `json:"title"`
		Originallink string `json:"originallink"`
		Link         string `json:"link"`
		Description  string `json:"description"`
		PubDate      string `json:"pubDate"`
	} `json:"items"`
}

type Header struct {
	Header map[string]string
}

type SendToNaverNewsInputDTO struct {
	Query string
}

type NewsManager struct {
	Http_caller http_caller.HttpCallerInterface
}

func NewNewsManager(
	http_caller http_caller.HttpCallerInterface,
) *NewsManager {
	return &NewsManager{
		Http_caller: http_caller,
	}
}

func NewNewsData() *NewsData {
	return &NewsData{}
}

func (domain_service *NewsManager) SendToNaverNews(input_dto SendToNaverNewsInputDTO) (*NewsData, error) {
	// HTTP 요청 헤더에 클라이언트 아이디와 클라이언트 시크릿을 추가
	clientId := "WyIgNwF9ekhEq8VxeeO4" //os.Getenv("NAVER_CLIENT_ID")
	clientSecret := "NGeR4NUTOK"       // os.Getenv("NAVER_CLIENT_SECRET")

	// 헤더 설정
	header := map[string]string{
		"X-Naver-Client-Id":     clientId,
		"X-Naver-Client-Secret": clientSecret,
	}

	key := "IT"
	// API 엔드포인트 설정
	url := "https://openapi.naver.com/v1/search/news.json?query=" + key + "&display=100"
	log.Println("url:", url)

	// API 호출
	response, err := domain_service.Http_caller.CallGetByUrlWithHeader(url, header)
	if err != nil {
		fmt.Println("API 호출 중 오류 발생:", err)
		return nil, err
	}
	defer response.Body.Close()
	// 응답 바디 읽기
	body, err := io.ReadAll(response.Body)
	if err != nil {
		fmt.Println("응답 바디 읽기 중 오류 발생:", err)
		return nil, err
	}

	log.Println("response body:", string(body))

	// JSON 파싱
	var newsData NewsData
	err = json.Unmarshal(body, &newsData)
	if err != nil {
		fmt.Println("JSON 파싱 중 오류 발생:", err)
		return nil, err
	}

	fmt.Println("newsData:", newsData.Items)

	return &newsData, nil
}
