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

## 선생님 이름과 학교 공유 DB

서버는 H2 파일 DB 하나에 학교 코드·교사 식별값·앱 설치별 이름 후보를 보관합니다. 기본 경로는 서버 실행 디렉터리의 `data/teacher-names.mv.db`이며, `SCHOOLZIP_NAMES_DB`로 확장자를 제외한 영구 저장 경로를 지정할 수 있습니다. 배포 시 이 경로를 영구 볼륨으로 유지하고, 서버를 정지한 상태에서 DB 파일을 백업하세요. `server/data/`는 Git에서 제외합니다.

- `GET /api/teacher-names/{code}?name=학교명`: 현재 교사 명단과 일치하는 이름 후보와 입력 기기 수.
- `PUT /api/teacher-names/{code}?name=학교명`: `X-Schoolzip-Installation`에 앱에서 생성한 64자리 임의 토큰을 보내고, `{"entries":[{"teacherId":"…","original":"김가*","value":"김가람"}]}` 형태로 해당 설치의 직접 입력 세트를 교체합니다. 빈 배열은 해당 설치의 제출을 철회합니다. 다른 설치의 제출은 수정하지 않습니다.

교사 식별값은 학교·학년도·원본 명단·명단 인덱스에 한정됩니다. 명단이 바뀌면 기존 이름은 기기에 보관하고, 설정의 ‘이전 명단 이름 연결하기’에서 이름/과목 유사도를 참고한 후보를 사용자가 직접 연결합니다. 과목 숫자 변경은 후보 정렬에만 사용하며 동일인으로 자동 확정하지 않습니다.

다른 사용자가 제출한 이름은 검증된 정보가 아닙니다. 앱은 미선택 상태의 후보 목록을 보여주며 기존 개인 설정은 덮어쓰지 않습니다. 같은 설치의 재전송은 중복 집계하지 않고, 가져온 이름은 새 입력으로 재전송하지 않습니다. 설치 토큰은 계정이나 실명 인증이 아니므로 입력 기기 수는 정확도나 독립적인 사람 수를 보증하지 않습니다. 서버는 원본 명단과 식별값을 대조하고 이름 길이/제어문자/세트 크기를 검사합니다.

전송에 실패한 개인 이름은 로컬에 남으며 다음 시간표 로드나 이름 수정 때 재전송합니다. 학교를 처음 선택했을 때 공유 후보가 있으면 적용 여부를 묻고, 취소한 뒤에도 설정의 ‘학교 공유 이름 불러오기’에서 다시 확인할 수 있습니다.
