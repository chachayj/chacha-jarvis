const VIDEO_HEIGHT_RATIO = 0.75;
const PORTRAIT_HEIGHT_RATIO = 1.15;

let targetVideo = null;

const canvas = document.getElementById("canvas");
const canvasContext = canvas.getContext("2d");
const tmpCanvas = document.getElementById("tmpCanvas");
const tmpCanvasContext = tmpCanvas.getContext("2d", {
  willReadFrequently: true,
});
canvas.width = document.body.clientWidth;
canvas.height = document.body.clientWidth * VIDEO_HEIGHT_RATIO; // video ratio
tmpCanvas.width = canvas.width;
tmpCanvas.height = canvas.height;

window.setTargetVideo = (videoElement) => {
  targetVideo = videoElement;
};

// Make video background transparent by matting
function makeBackgroundTransparent(timestamp) {
  // console.log('makeBackgroundTransparent');
  // Throttle the frame rate to 30 FPS to reduce CPU usage
  if (targetVideo && timestamp - previousAnimationFrameTimestamp > 30) {
    // video = document.getElementById('video')
    let startPosX = 0;
    let endPosX = 0;
    // console.log(targetVideo.id)
    if (targetVideo.id === "video-idle") {
      const portraitWidth = targetVideo.videoWidth / 2.6666;
      startPosX = (targetVideo.videoWidth / 2 - parseInt(portraitWidth / 2, 10)) * 0.725;
      endPosX = startPosX + parseInt(portraitWidth / 2, 10);
      // console.log('video-idle', targetVideo, startPosX, 0, targetVideo.videoWidth, targetVideo.videoHeight)
      // console.log(targetVideo.videoWidth, portraitWidth)
      tmpCanvasContext.drawImage(
        targetVideo,
        (startPosX + endPosX) / 2 * VIDEO_HEIGHT_RATIO,
        0,
        portraitWidth,
        portraitWidth * PORTRAIT_HEIGHT_RATIO,
        0,
        0,
        tmpCanvas.width * 0.725,
        tmpCanvas.height
      );
    } else {
      const centerPosX = ((tmpCanvas.width / 2) - (targetVideo.videoWidth / 2)) * 0.725;
      // tmpCanvasContext.drawImage(
      //   targetVideo,
      //   0,
      //   0,
      //   targetVideo.videoWidth,
      //   targetVideo.videoHeight
      // );
      tmpCanvasContext.drawImage(
        targetVideo,
        0,
        0,
        targetVideo.videoWidth,
        targetVideo.videoWidth * PORTRAIT_HEIGHT_RATIO,
        centerPosX,
        0,
        tmpCanvas.width * (1 / 0.725),
        tmpCanvas.height
      );
    }

    let transparentPixels = 0;
    let lastAlphaValue = 0;
    if (targetVideo.videoWidth > 0) {
      let frame = tmpCanvasContext.getImageData(
        0,
        0,
        tmpCanvas.width,
        tmpCanvas.height
      );
      for (let i = 0; i < frame.data.length / 4; i++) {
        let r = frame.data[i * 4 + 0];
        let g = frame.data[i * 4 + 1];
        let b = frame.data[i * 4 + 2];
        if (g - 150 > r + b) {
          // Set alpha to 0 for pixels that are close to green
          frame.data[i * 4 + 3] = 0;
        } else if (g + g > r + b) {
          // Reduce green part of the green pixels to avoid green edge issue
          adjustment = (g - (r + b) / 2) / 3;
          r += adjustment;
          g -= adjustment * 2;
          b += adjustment;
          frame.data[i * 4 + 0] = r;
          frame.data[i * 4 + 1] = g;
          frame.data[i * 4 + 2] = b;
          // Reduce alpha part for green pixels to make the edge smoother
          a = Math.max(0, 255 - adjustment * 4);
          frame.data[i * 4 + 3] = a;
          transparentPixels += 1;
          lastAlphaValue = a;
        }
      }

      canvasContext.putImageData(frame, 0, 0);

      // console.log('convert alpha pixels', transparentPixels, lastAlphaValue)
    }

    previousAnimationFrameTimestamp = timestamp;
  }

  window.requestAnimationFrame(makeBackgroundTransparent);
}

/* nav (center) */
const navItems = document.getElementsByClassName('nav-item');
const navPointer = document.querySelector('#nav .pointer');
console.log(navItems);
for(let i = 0; i<navItems.length; i+=1) {
  // console.log(navItem);
  navItems[i].onclick = (e) => {
    const targetID = e.currentTarget.dataset.nav;
    const navItems = document.getElementsByClassName('nav-item');
    // console.log('targetID', targetID);
    // 선택 메뉴의 Selected 표시 
    for(let i = 0; i<navItems.length; i+=1) {
      // console.log(navItems[i]);
      if (navItems[i].dataset.nav === targetID) {
        navItems[i].classList.add('selected');
        console.log(navItems[i], 'offsetLeft', navItems[i].offsetLeft)
        navPointer.style.left = navItems[i].offsetLeft+'px';
      } else {
        navItems[i].classList.remove('selected');
      }
    }

    // 선택 메뉴에 해당하는 Content 표시
    // console.log(e.currentTarget.dataset.nav);
    const contents = document.getElementsByClassName('main-content');
    for(let j = 0; j<contents.length; j+=1) {
      if (contents[j].id !== targetID) {
        contents[j].classList.add('hidden');
      } else {
        contents[j].classList.remove('hidden');
      }
    }
  }
}

/* Bottom Sheet */
var handle_wrap = document.getElementsByClassName('bottom_sheet_handle_wrap')[0];
var bottom_sheet = document.getElementsByClassName('bottom_sheet')[0];
var up_sensor = document.getElementsByClassName('up_sensor')[0];
let bottom_touch_start = 0;
let bottom_scroll_start;

//up_sensor에서 터치가 움직였을 경우 (바텀시트를 건드렸을 경우) -> 바텀시트를 올림
up_sensor.addEventListener("touchmove", (e) => {
  // bottom_sheet.style.height = 70 + "%" //바텀시트 height를 올리기 10% -> 70%
  // up_sensor.style.height = 70 + "%"; //up_sensor도 따라가기
  // setTimeout(function () {
  //   up_sensor.style.display = "none";
  // }, 1000); // 바텀시트가 올라간 후, up_sensor 사라지기

  // console.log(
  //   'touchMove',
  //   e.touches[0].clientX,
  //   e.touches[0].clientY
  // )
  // console.log('calc bottom sheet height', document.body.clientHeight - e.touches[0].clientY);
  bottom_sheet.style.height = parseInt(document.body.clientHeight - e.touches[0].clientY, 10) + 'px';
});

up_sensor.addEventListener("touchend", (e) => {
  console.log('document', document.body.clientHeight);
  console.log(
    'touchEnd',
    e.changedTouches[0].clientX,
    e.changedTouches[0].clientY
  )
})


//맨 위에서 아래로 스크롤했을 경우
bottom_sheet.addEventListener("touchstart", (e) => {
  bottom_touch_start = e.touches[0].pageY; // 터치가 시작되는 위치 저장
  bottom_scroll_start = bottom_sheet.scrollTop //터치 시작 시 스크롤 위치 저장
});

bottom_sheet.addEventListener("touchmove", (e) => {
  //유저가 아래로 내렸을 경우 + 스크롤 위치가 맨 위일 경우
  if (((bottom_touch_start - e.touches[0].pageY) < 0) && (bottom_scroll_start <= 0)) {
    //바텀시트 내리기
    bottom_sheet.style.height = 10 + "%"
    up_sensor.style.display = "block"; //up_sensor 다시 나타나기
    up_sensor.style.height = "10%"; //up_sensor height 다시 지정
  };
});


//맨 위 핸들을 아래로 당겼을 경우
handle_wrap.addEventListener("touchstart", (e) => {
  bottom_touch_start = e.touches[0].pageY; // 터치가 시작되는 위치 저장
});
handle_wrap.addEventListener("touchmove", (e) => {
  //사용자가 아래로 내렸을 경우
  if ((bottom_touch_start - e.touches[0].pageY) < 0) {
    //바텀시트 내리기
    bottom_sheet.style.height = 10 + "%"
    up_sensor.style.display = "block"; //up_sensor 다시 나타나기
    up_sensor.style.height = "10%"; //up_sensor height 다시 지정
  };
});

const greenCircle = document.createElement('greenCircle')
// .getElementById('greenCircle');

document.body.appendChild(greenCircle);

const startSpeechAnimation = () => {
  console.log("startSpeechAnimation start")
  greenCircle.classList.add('animate');
  // document.getElementById("video-idle").muted = false;
    
  setTimeout(() => {
    console.log("startSpeechAnimation end")
    greenCircle.classList.remove('animate');
    // document.getElementById("muted-cover").hidden = true;
  }, 10000); // Adjust the duration of the animation as needed
};

const getTalkHistories = (userId) => {
  fetch(`https://jarvis/user/${userId}/history`)
  .then(response => {
    if (!response.ok) {
      throw new Error('Network response was not ok');
    }
    return response.json();
  })
  .then(data => {
    // 데이터를 사용하는 코드 작성
    // console.log(data); // 데이터 확인을 위한 로그 출력
    const { histories } = data;
    
    console.log("histories : ", histories)
    if (histories !== null) {
      // 파싱된 데이터를 활용하여 원하는 작업 수행
      histories.forEach(history => {
        const { timestamp, question, answer } = history;
        const koreanTime = new Date(timestamp * 1000).toLocaleString('ko-KR', {timeZone: 'Asia/Seoul'});
        // console.log(`Question: ${question}`);
        // console.log(`Answer: ${answer}`);
        // console.log(`Timestamp (Korean Time): ${koreanTime}`);
        window.appendChat('mine', question, koreanTime);
        window.appendChat('jarvis', answer, koreanTime);
      });
    }
  })
  .catch(error => {
    console.error('There was a problem with the fetch operation:', error);
  });
};



window.setTargetVideo(document.getElementById("video-idle"));
window.requestAnimationFrame(makeBackgroundTransparent);

const createUserByUUID = (uuid) => {
  // console.log("createUserByUUID call ", uuid)
};


// UUID 생성 함수
function generateUUID() {
  // RFC4122 버전 4 기반의 UUID 생성
  // 출처: https://stackoverflow.com/a/2117523
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random() * 16 | 0,
          v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
  });
}

// 로컬 스토리지에서 UUID 가져오기
var uuid = localStorage.getItem('uuid');

// UUID가 없으면 생성
if (!uuid) {
  console.log("uuid가 없음: ", uuid)
  uuid = generateUUID();
  // 생성한 UUID를 로컬 스토리지에 저장
  localStorage.setItem('uuid', uuid);
  console.log("uuid setItem: ", uuid)

  // createUserByUUID(uuid)
  // getTalkHistories(uuid)
} else {
  console.log("uuid가 있음: ", uuid)
  // getTalkHistories(uuid)
}


function getParameterByName(name, url) {
  if (!url) url = window.location.href;
  name = name.replace(/[\[\]]/g, "\\$&");
  var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
      results = regex.exec(url);
  if (!results) return null;
  if (!results[2]) return '';
  return decodeURIComponent(results[2].replace(/\+/g, " "));
}


const targetElement = document.getElementById('header');
  // background-color: #36373A

  // 요소의 배경색을 초록색으로 설정합니다.
targetElement.style.backgroundColor = 'green';
console.log('pendingAPI has been reset to false');
