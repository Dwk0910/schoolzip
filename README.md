# school.zip · 스쿨집

컴시간에서 학교를 검색하고 이번 주와 다음 주의 학년·반별 시간표를 보는 iOS·Android 앱입니다.

## 서버 실행

Java 21, Maven 3.9+, Python 3.9 이상이 필요합니다. Spring Boot가 학교 검색과 시간표 API를 제공하며, 컴시간 자료는 pycomcigan 1.4.5로 읽습니다. 서버는 검색 결과와 학교별 주간 시간표를 2분간 캐시합니다.

Windows PowerShell에서 저장소 루트를 기준으로 실행하세요.

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:SCHOOLZIP_PYTHON = (Resolve-Path .\.venv\Scripts\python.exe).Path
mvn spring-boot:run
```

macOS 또는 Linux에서는 가상 환경의 실행 파일이 `.venv/bin/python`입니다. `SCHOOLZIP_PYTHON`에 해당 실행 파일의 절대 경로를 지정하고 server 디렉터리에서 서버를 시작하세요.

## 모바일 앱 실행

Flutter stable과 대상 플랫폼 SDK를 설치한 후 별도 터미널에서 실행하세요.

```sh
cd mobile
flutter pub get
flutter run
```

Android 에뮬레이터는 기본적으로 `http://10.0.2.2:8080`, iOS 시뮬레이터는 `http://localhost:8080`에 연결합니다. 실제 기기는 기기에서 접근할 수 있는 서버 주소로 실행하세요. 배포 빌드에는 HTTPS 주소를 사용하세요.

```sh
flutter run --dart-define=API_BASE_URL=https://your-server.example
```

학교 이름을 검색하고 지역과 학교를 확인한 뒤 학년·반과 주차를 선택하세요. 날짜는 컴시간이 반환한 시작일을 따르며, 변경된 수업에는 대체 표시가 붙습니다.

## API

- `GET /api/schools?q=오남` — 학교 이름, 지역, 컴시간 학교 코드
- `GET /api/timetable?name=오남고등학교&code=43373&week=0` — 학교별 주간 시간표. week 값은 이번 주 0, 다음 주 1입니다. grades의 학년·반 키 아래 요일별 수업 목록이 들어 있습니다.

- `GET /api/meals?name=오남고등학교&region=경기&date=2026-06-19` — 나이스 학교명과 지역으로 조회한 날짜별 식단입니다. 등록된 식단이 없으면 빈 배열을 반환합니다. 서버에 `NEIS_API_KEY` 환경 변수를 지정할 수 있습니다.
