# PROCESS_LOG — 작업 기록 (과정 70점의 핵심 근거)

> 표준 헤더(CLAUDE.md 등)를 로드했다면 에이전트가 알아서 채워 줍니다. 비면 직접 채우세요.
> 원칙: **실제로 시킨 프롬프트를 그대로 인용**할 것. 요약만 있으면 점수가 깎입니다.

## 작성자 정보 (개인별 로그 — 본인 것만)
- 팀명: C팀 (teamC)
- 본인 이름(작성자): _(미정 — 확정 시 파일명도 `teamC_<이름>_PROCESS_LOG.md`로 변경)_
- 공통과제(우리 팀이 자동화한 반복 수작업): _(미정 — 주제 선정 후 기입)_
- 내가 맡은 부분: 팀장(주장) — 저장소(Fork) 생성·환경 세팅·취합/제출
- 자유과제(있으면): _(미정)_

> **이 로그는 본인 것만 작성**합니다. 각자 자기 PC·계정으로 작업해 개인 로그를 남기고, 제출 시 **영문 파일명** `<팀영문명>_<이름로마자>_PROCESS_LOG.md`(예: `teamA_kim_PROCESS_LOG.md`)로 저장하세요. **한글 파일명은 압축 시 깨지므로 금지** — 한글 팀명·이름은 위 '작성자 정보'에 적습니다. 운영자가 팀별로 모아 채점합니다(전원 참여 = 팀별 개인 로그 수).

## 효과 측정 (Before → After, 결과 ⑥ 채점용 — 형식 자유)
> **지표는 자기 업무에 맞게 고름 — 강제 항목 없음.** (예시, 해당되는 것만) 소요 시간 · 반복 횟수 · 다루는 자료/파일 수 · 손 가는 단계 수 · 품질·일관성 · 오류/누락 · 커버리지 등. 정량이 어려우면 정성도 인정.

| 지표(자기 업무에 맞게) | Before(기존 수작업) | After(에이전트화) |
|------|------|------|
|  |  |  |
|  |  |  |

## 사용 기법 (권장·가점, 필수 아님)
- [ ] (a) 서브에이전트 / 역할 분담
- [x] (b) 외부 도구·데이터 연동 (파일/API/MCP/사내데이터) — Notion MCP로 대회 안내 분석, git/GitHub API로 저장소 점검
- [ ] (c) 재사용 산출물 (스킬 / 프롬프트셋 / CLAUDE.md / 서브에이전트 구성)

---

## 작업 로그 (단계마다 1개씩 누적 / 시간순)

### [#1] 대회 안내 분석 + 스타터킷 환경 세팅 (Notion MCP · git)
- 작성자(팀원): MS (C팀 팀장)
- 목표: 대회 규칙을 정확히 파악하고, 팀 저장소(Fork)와 로컬 작업 환경을 제출 가능한 상태로 세팅한다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "mcp 설정 ... 접근하도록" / "재귀적으로 분석하기"
  > "해커톤 킷 클론하기"
  > "팀장이 나인데 제대로 한건지 확인 노션에 있음"
- 사용한 기법(있으면): (b) 외부 도구·데이터 연동 — Notion MCP(OAuth)로 대회 안내 8개 페이지 재귀 분석, GitHub API로 Fork 검증
- 결과:
  - Notion MCP 연결(OAuth) → 대회 안내 페이지 트리(루트+하위 7) 전부 분석. 핵심: 과정 70 : 결과 30, PROCESS_LOG 기반 채점.
  - 스타터킷 `git clone` 완료, 리모트를 팀 Fork(`duryeong/geosr-hackathon-kit-team-c`)로 변경.
  - 팀장 세팅 점검: Fork 정상(parent=`limitda83/geosr-hackathon-kit`), 로컬 동기화 OK. (팀원 Collaborators 초대는 본인이 GitHub에서 확인 예정.)
- 막힘 → 해결:
  - `gh` CLI 없음 → GitHub REST API(curl)로 Fork 메타 확인.
  - 구버전 git이라 `git restore` 미지원 → `git checkout --`로 템플릿 복구.

### [#2] 자동화 대상 폴더 분석 + 레거시 파이프라인 복구·현대화
- 작성자(팀원): MS (C팀 팀장)
- 목표: 실제 작업폴더(`/data1/syjeong/.../02_Hackathon`)의 GEO-ADCIRC 모델 스크립트를 읽고, 깨진 레거시 자동화를 "돌아가는 상태"로 복구한다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "README_team_c.md 분석해 이게 우리 자동화 할 대상임"
  > "현재 대상 폴더 보고 돌아가는 상황으로 만들어봐"
- 사용한 기법(있으면): (b) 외부 도구·데이터 연동 — 서버 작업폴더 직접 탐색·스크립트 분석 / (c) 재사용 산출물 — `automation/` 드라이버·모니터 스크립트
- 결과:
  - 실제 모델 = ADCIRC+SWAN(`padcswan`, 992코어 MPI, wave01~28) 확인 → 본수행은 클러스터 전용.
  - 레거시 `check-tsw_hotstart.sh`(2022)의 3가지 결함 발견·수정:
    (1) 경로 하드코딩(`/home/storm/2022`) → 환경변수 분리,
    (2) 단계 호출 불일치(03을 post로 호출, onlytide 누락) → `01_pre→02_model→03_onlytide→04_post`로 정정,
    (3) `/tmp` 카운터 상태관리 → 영속 상태파일(처리완료 케이스 목록)로 견고화.
  - `automation/run_pipeline.sh`(오케스트레이터) + `automation/check_typhoon.sh`(모니터) + `README.md` 작성.
  - **DRY_RUN 테스트 통과**: 파이프라인 4단계 end-to-end 흐름 OK, 모니터 신규케이스 감지·중복방지·상태기록 OK.
- 막힘 → 해결:
  - 클러스터(mpirun) 없어 실측 불가 → `DRY_RUN=1` 안전모드 추가로 흐름 검증, 실제 수행은 mpirun 가용 시에만 허용.

### [#3] 대상 변경(padcswan→padcirc) 재검토 + 오케스트레이터 정합
- 작성자(팀원): MS (C팀 팀장)
- 목표: 팀원(SY/JM)이 모델을 padcirc(코어 가변)로 전환했으므로, 내 자동화 파이프라인을 새 수행 스크립트와 정합시킨다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "깃헙에 새로운게 있는지 풀해봐"
  > "대상이 변경 되었으니 다시 검토해"
- 사용한 기법(있으면): (b) 외부 도구·데이터 연동 — 변경된 서버 스크립트 재분석 / (c) 재사용 산출물 — 오케스트레이터 업데이트
- 결과:
  - 변경 파악: padcswan(ADCIRC+SWAN, 992코어 고정) → **padcirc(ADCIRC 단독, SWAN 미연동, 코어 가변)**. 모델 수행이 `02_runp_model.csh` → `02_runp_model_padcirc.csh <코어수>`로 바뀜. adcprep도 3단계(992p) → 표준 2단계(--partmesh/--prepall).
  - `run_pipeline.sh`: `NP`(코어수, 기본 120) 인자 추가, 02단계를 `02_runp_model_padcirc.csh $NP` 호출로 교체, 로그에 모델/코어 표기.
  - `check_typhoon.sh`: `NP` 환경변수 전달 추가. `README.md`: padcirc 전환·운영(83번 서버) 반영.
  - **DRY_RUN 재검증 통과**: `02_runp_model_padcirc.csh 120` 정상 호출 확인.
- 막힘 → 해결:
  - 팀원과 병렬 작업 → 동시 푸시 충돌. pull→merge(timestamps 양쪽 보존)로 해결 후 정합.

### [#4] 수동 순차 수행기(run_manual.sh) 작성 — 실행은 하지 않음
- 작성자(팀원): MS (C팀 팀장)
- 목표: 담당자가 소스 폴더에서 01→02→03→04를 손으로 순서대로 돌릴 수 있게 세팅(누락·순서실수 방지). 단, 모델 수행은 하지 않음.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "수동 수행에 대해 순차적으로 수행이 가능하도록 세팅 수행은 하지마"
- 사용한 기법(있으면): (c) 재사용 산출물 — `automation/run_manual.sh`
- 결과:
  - `run_manual.sh` 작성: 소스 폴더 in-place 수행, 단계 전 확인(Enter)/단일단계(-s)/연속(-y)/코어수(-n) 지원. padcirc 스크립트 우선 사용, 없으면 원본 fallback.
  - 소스 폴더가 아니면 안전 가드로 아무것도 실행 안 함.
  - **검증은 비실행으로만**: `bash -n`(문법 OK) + 안전가드 동작 + `--help` 확인. **모델(mpirun/padcirc)은 실행하지 않음**(지시대로).
- 막힘 → 해결: 없음.

### [#5] 수행 가능 세팅 — 입력/권한 블로커 진단 + setup_run.sh 작성
- 작성자(팀원): MS (C팀 팀장)
- 목표: 수동 수행이 실제로 가능하도록 소스 폴더의 수행 블로커를 찾아 보정 세팅(모델은 실행 안 함).
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "수행이 가능하도록 세팅이 필요함"
- 사용한 기법(있으면): (b) 외부 도구·데이터 연동 — 실행파일 strings/소스 grep으로 입력경로 추적 / (c) 재사용 산출물 — setup_run.sh
- 결과 (진단으로 확인된 블로커):
  - (1) `Wind/typhoon.in` 누락 — hotstart/onlytide/Model 실행파일이 `../Wind/typhoon.in`을 읽는데 파일이 없음(루트 typhoon.in=NARITEST만 존재).
  - (2) `Run_NDMI_wind.csh`의 `cp -f ../typhoon.in ./`가 주석 → 매 수행 시 (1) 재발.
  - (3) `Model/hotstart/padcirc`·`Model/onlytide/padcirc` 실행권한 없음.
  - (참고/미보정) `Model/hotstart`·`onlytide` 수행스크립트는 아직 레거시 992코어 고정(`np=992`, wave01~28) → 83번 서버 가변코어 미대응. 모델담당(SY)과 협의 필요로 미수정.
  - `automation/setup_run.sh`(--check 점검 / --apply 보정, 백업 포함) 작성. **--check로 실제 폴더 진단 통과(변경 없음)**.
- 막힘 → 해결:
  - 타 사용자(syjeong) 폴더 직접 수정이 자동모드에서 차단 → 보정 로직을 setup_run.sh로 분리해 팀장이 직접 --apply 실행하도록 함. 모델은 미실행.

### [#6] Phase 4~5 — AI 의사결정 에이전트 + 보고서 자동작성 구현
- 작성자(팀원): MS (C팀 팀장)
- 목표: 폭풍해일 예측 플랫폼(`192.168.2.77:5173`, syjin)을 참고해, 자동화 파이프라인의 ④의사결정·⑤보고서 단계를 구현한다. 플랫폼의 대화형 경로(`/api/chat`)와 중복하지 않고, 크론 파이프라인이 새 케이스마다 사람 개입 없이 판단·보고서를 자동 생성하는 배치 경로를 만든다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "http://192.168.2.77:5173/ 사이트 참고"
  > (작업 방향 선택) "AI 에이전트 연동"
- 사용한 기법(있으면): (b) 외부 도구·데이터 연동 — 플랫폼 `/api/stations`(32개소 임계값) 스냅샷·Claude Messages API 연동 / (c) 재사용 산출물 — `automation/agent/` 모듈, 테스트베드 샘플, Claude 클라이언트 래퍼
- 결과:
  - `automation/agent/risk.py` — 관측소 임계값(관심/주의/경계/위험) 대비 최대 해일고 비교로 위험등급을 **결정론적으로** 판정(재현·검증 가능)
  - `automation/agent/claude_client.py` — Claude Messages API 래퍼(requests 기반, SDK 불필요). 키 없거나 호출 실패 시 폴백
  - `automation/agent/ai_decision.py` (Phase 4) — 모델결과+임계값 → 위험판정 → Claude 종합판단·권고 → `decision.json`
  - `automation/agent/generate_report.py` (Phase 5) — `decision.json` → 의사결정 보고서 초안 `.md`(`--polish` 시 도입부 Claude 윤문)
  - `automation/post_to_agent.sh` — 04_post → Phase 4 → Phase 5 글루
  - `automation/samples/model_results_NARITEST.json` — 가상태풍 테스트베드 입력(32개소), `samples/example_outputs/` 예시 산출물
  - 설계 원칙: **등급은 규칙, 해석은 AI, 키 없으면 자동 폴백** → 파이프라인 무중단.
  - **테스트베드 end-to-end 검증 통과**(`./post_to_agent.sh 2025_90_NARITEST`): 최고등급 '위험', 위험관측소 17/32개소. 더미키 401→폴백 전환·네트워크 정상까지 확인.
- 막힘 → 해결: 운영 파이썬에 anthropic SDK·API 키 부재 → SDK 의존 없이 `requests`로 Messages API 직접 호출 + 키 없을 때 규칙기반 폴백으로 항상 동작하도록 설계.

### [#7] AI 호출을 Claude Code(CLI) headless 방식으로 전환 + 외부접근 대시보드 서버 기동
- 작성자(팀원): MS (C팀 팀장)
- 목표: (1) 서버에 Anthropic API 키를 둘 수 없는 제약을 반영해 Claude 호출을 `claude` CLI headless(`-p`) 방식으로 바꾼다. (2) Phase 4~5 결과를 외부 호스트(192.168.6.70)에서 볼 수 있는 웹 대시보드 서버를 올린다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "현재 서버의 클로드코드에 프롬프트를 직접 던지는 방식으로 api 사용할수 없음"
  > "외부 192.168.6.70 에서 접근 가능하도록 서버 올리기"
- 사용한 기법(있으면): (b) 외부 도구 연동 — `claude -p --append-system-prompt --output-format text` 서브프로세스 호출 / (c) 재사용 산출물 — `server.py`, `serve.sh`
- 결과:
  - `claude_client.py` 재작성: 기본 전송수단을 **Claude Code CLI**(`claude -p`)로 변경. 키 불필요, Claude Code 인증 사용. 미설치·타임아웃·오류 시 규칙기반 폴백. (`CLAUDE_TRANSPORT=api` 로 HTTP API 경로도 선택 가능, 모델은 `CLAUDE_MODEL` 별칭/전체명.)
  - 검증: `./post_to_agent.sh 2025_90_NARITEST` → 판단원 `claude-code-cli`, 실제 Claude 종합판단 생성 확인.
  - `agent/server.py`(표준 라이브러리만, 의존성 0): `/`(목록)·`/case/<CASE>`·`/decision`·`/report`·`POST /run`(웹 버튼 재실행)·`/dataviz`·`/healthz`. **0.0.0.0 바인딩**으로 외부 접근.
  - `agent/serve.sh` start/stop/status(setsid+nohup, 세션 종료에도 유지).
  - **가동·외부접근 검증**: `192.168.2.83:8787` GET/`/case`/`/report` 200, `POST /run` 303(재실행 성공). 경로 `192.168.6.70 via 192.168.2.1 src 192.168.2.83` 확인.
- 막힘 → 해결: 툴에서 띄운 백그라운드 프로세스가 셸 종료 시 정리됨 → `serve.sh`에서 `setsid+nohup`으로 세션 분리해 영속 기동하도록 처리(새 셸에서 생존 확인). 접속 URL은 외부망 출발지 IP(192.168.2.83)를 `ip route get`으로 골라 표기.

### [#8] 풀 시나리오 파이프라인 구축 — 멀티에이전트(ultracode) 워크플로
- 작성자(팀원): MS (C팀 팀장)
- 목표: 통보문 모니터링 → (신규/위험반경진입/업데이트 감지) → 바람장(dry-run) → 해일·해수위 예측(dry-run) → 공간장 표출 → 맵 클릭 시 해수위(좌축)·해일고(우축) 시계열, 전 과정을 동작하는 데모로 구현.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "분석 시나리오를 상세하게 설명하면 태풍 통보문(기상청)을 주기적으로 모니터링 -> 새로운 태풍이 생기거나 -> 위험 반경 안에 들어와서 ... 통보문 업데이트 -> 태풍 바람장 만들어지기(dry-run) -> 해수위 해일고 예측(dry-run) -> 공간장 표출 -> 맵의 특정 위치를 클릭하면 ... 해수위(좌측축), 해일고(우측축)이 시계열로 표출"
  > "ultracode 로 멀티 에이전트로 수행"
- 사용한 기법(있으면): (a) 서브에이전트 — Workflow 멀티에이전트(데이터생성·백엔드API·프론트엔드·모니터링 4개 빌드 + 통합검증, 총 5에이전트) / (b) 도구·데이터 연동 / (c) 재사용 산출물
- 결과 (데이터 계약 고정 후 병렬 빌드 → 통합검증 PASS, 자동 회귀검사 포함):
  - `agent/scenario.py` — dry-run 시나리오 생성기(표준 라이브러리만). NARITEST 트랙 3시간 간격 21스텝, 트랙/통보문(발생·위험반경진입·강도변화·상륙)/관측소 시계열(천문조 tide·해일고 surge·총수위 total)/해일고 공간장(24×24×21). surge 첨두는 기존 `samples/model_results_NARITEST.json` 재사용으로 Phase4와 일관.
  - `agent/server.py`(편집) — 신규 API: `/api/scenario`·`/api/track`·`/api/field(?t=)`·`/api/timeseries/<sid>`·`/api/monitor`·`/scenario/<case>`(프론트)·`/web/<file>`(정적, 경로탈출 차단). 기존 라우트 전부 보존.
  - `agent/web/scenario.html` — Leaflet 지도(트랙·이동 태풍마커·해일고 공간장 캔버스 오버레이·관측소 등급색 마커) + 시간 슬라이더/재생 + 관측소 클릭 시 Chart.js **이중 Y축**(좌:해수위 total/tide, 우:해일고 surge) 시계열·임계선. CDN만, 빌드도구 없음.
  - `monitor_scenario.sh` + `agent/advisory_feed.py` — 통보문 모니터링 dry-run: 4단계 감지→바람장→예측(scenario.py 재생성)→`reports/monitor_state.json` 갱신. `--once`(crontab 멱등)/`--interval`/`PIPELINE=0` 지원, `check_typhoon.sh` 스타일.
  - **검증**: 통합검증 12/12 PASS. 내가 직접 외부 IP 재확인 — `http://192.168.2.83:8787/scenario/2025_90_NARITEST` 및 전 API 200, 부산 시계열 21포인트(surge max 262.2 / total max 340.1).
- 막힘 → 해결: 임계값(thresholds)이 관측소별로 150~1021cm로 편차가 커, 프론트 에이전트가 "thresholds는 해일고(surge)보다 총수위(total) 규모에 부합"하다고 판단해 맵 등급판정·임계선을 total_cm 기준으로 적용함. → Phase4 `risk.py`는 surge 기준이라 의미 정의가 갈림. **예보관 기준(해일고 vs 총수위) 확정 필요** — 다음 단계로 통일 예정.

### [#9] 시나리오 GUI 2:1 재구성 + 공간장 3종(바람장/해수위/해일고) — 멀티에이전트(ultracode)
- 작성자(팀원): MS (C팀 팀장)
- 목표: 화면을 좌:우=2:1로 재구성. 좌측(큰 영역)=지도 위 태풍+공간장 표출이며 바람장/해수위/해일고 전환 가능. 우측(작은 영역)=위에서 아래로 ① 태풍 정보 ② 클릭된 관측소 시계열(해수위·해일고).
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "gui의 구성을 바뀌야함 좌우를 2:1로 2을 공간 맵 위에 태풍,공간장(바람장, 해수위, 해일고)표출을 가능해야하고 우측에 상단부터 차례대로 태풍정보, 클릭된 시계열 정보(해수위, 해일고) 정보가 나타나야함"
  > "ultracode로 수행"
- 사용한 기법(있으면): (a) 서브에이전트 — Workflow 멀티에이전트(데이터·백엔드·프론트 3 빌드 + 통합검증, 4에이전트)
- 결과 (통합검증 PASS, 회귀 없음; 내가 외부 IP 재확인 완료):
  - `agent/scenario.py` — 공간장을 `field.frames` → `field.vars`로 확장. **surge(해일고)·sealevel(해수위=조위공간장+해일고)·wind(바람장: speed/u/v)** 3종, 각 [time][24][24]. 범위 검증: surge 0~140cm, sealevel −12~299cm, wind 4~51m/s.
  - `agent/server.py` — `/api/field/<case>?var=surge|sealevel|wind[&t=]` 지원(스칼라는 frames/values, wind는 speed/u/v). 잘못된 var 400, 범위초과 404. 기존 라우트 회귀 없음.
  - `agent/web/scenario.html` — 점진 리팩터로 기존 차트/마커/슬라이더 로직 보존하며: CSS grid `2fr 1fr`(≤900px 세로 스택, invalidateSize), 좌측 지도 공간장 전환 세그먼트([바람장][해수위][해일고])+변수별 범례, 해수위/해일고 히트맵·바람장 화살표(u/v subsample) 오버레이, 우측 상단 **태풍 정보 카드**(통보문 status·중심위경도·중심기압·최대풍속·강풍반경, track[idx] 실시간) + 하단 **이중축 시계열**(좌 해수위/천문조, 우 해일고+임계선).
  - **검증**: 외부 IP 200 — `?var=surge|sealevel|wind` 200, `?var=bad` 400, `/scenario/...` HTML에 `grid-template-columns`·바람장/해수위/해일고·중심기압·최대풍속·강풍반경·`var=wind`·`var=sealevel` 모두 포함. monitor_scenario.sh 멱등 회귀 OK.
- 막힘 → 해결: 없음(데이터 계약 고정 후 순차 빌드라 충돌 없음). 접속: http://192.168.2.83:8787/scenario/2025_90_NARITEST

### [#10] 실측 모델 출력(JONGDARI 2024) 해석 가능성 탐색
- 작성자(팀원): MS (C팀 팀장)
- 목표: 실제 ADCIRC 모델 출력 폴더를 탐색해, 우리 대시보드/파이프라인 데이터 계약으로 해석·연동 가능한지 확인.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "샘플 데이터 위치는 다음과 같음 해석할 수 있는지 탐색해봐 /data1/syjeong/2026/Inundation/02_Hackathon/00_Ref/01_Model_Output/2024_09_JONGDARI_202408201600_west/Model"
- 사용한 기법(있으면): (b) 외부 도구·데이터 연동 — 서버 실측 데이터 직접 탐색(헤더/포맷 분석)
- 결과: **표준 ADCIRC+SWAN ASCII, 전부 해석 가능**으로 확인(태풍 JONGDARI 2024, 기준 2024-08-20 16:00, west 격자). 매핑:
  - `loc.dat`(33개소, **DT_ID** 우리 stations.json과 동일) / `3.MAX_surge_height_cm...`(관측소별 최대 해일고cm+첨두) / `1.`·`2.`(최대 해수위 m·DL cm)
  - `fort.61`(해수위 시계열 33개소×360스텝×10분 m) / `MAX_SWAN_HS_STATION.OUT`(유의파고) / `maxele.63`(58만노드)+`fort.14`(좌표, 공간장) / `fort.63`(전노드 시계열) / `CHECK.dat`(관측소↔노드) / `fort.22`(트랙)
  - 추출 도구 존재: `extract_maxelev.py`, `FIND_NODE_EXPORT_FORT.63`
  - 유의: 해일고 *시계열*은 fort.61(총수위)−`03_onlytide`(천문조) 차분 필요(최대 해일고는 파일3에 계산됨). 폴더는 root:datagroup 읽기전용 → 산출물은 reports/로 복사.
- 다음 단계(제안): (B) loc.dat+파일3 으로 실측 model_results.json → Phase4~5 실데이터 1회전 → (A) 어댑터로 대시보드 새 케이스 2024_09_JONGDARI 풀 연동.
- 막힘 → 해결: 없음(탐색).

### [#11] JONGDARI 실측 ADCIRC 출력 → 대시보드 새 케이스(2024_09_JONGDARI) 연동 — 멀티에이전트(ultracode)
- 작성자(팀원): MS (C팀 팀장)
- 목표: 실측 ADCIRC+SWAN 출력(태풍 JONGDARI 2024)을 어댑터로 우리 scenario 포맷으로 변환해 대시보드에 실데이터 케이스로 추가.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "A. JONGDARI 실데이터를 어댑터로 변환해 대시보드에 새 케이스(2024_09_JONGDARI)로 추가 (ultracode 멀티에이전트로 수행)"
- 사용한 기법(있으면): (a) 서브에이전트 — Workflow(정찰 2병렬 → 어댑터 빌드 → 통합검증, 4에이전트) / (b) 외부 데이터 연동(실측 ADCIRC 파싱)
- 결과 (통합검증 PASS, 회귀 없음; 내가 외부 IP 재확인):
  - `agent/ingest_model_output.py` 신규 — 실측 폴더(REF) → `scenario_2024_09_JONGDARI.json`(989KB) + `model_results_2024_09_JONGDARI.json` 생성.
    · 관측소: `loc.dat` 33개소(DT_ID), thresholds 는 stations.json DT_ID 크로스워크 매칭(32/33; 안흥·위도·마산·포항은 코드상이 동일관측소라 매핑, 흑산도 DT_0035는 대응없어 thresholds 생략).
    · **해수위 시계열 실측**: `fort.61`(총수위 m×100). 시간축 fort.15 WTIMINC 기준 UTC, 10분→서브샘플 60스텝(2024-08-19 03:10Z~08-21 15:00Z).
    · 해일고: onlytide 부재로 `3.MAX_surge`(실측 최대·첨두)로 bump 근사, tide=total−surge. max_surge/peak=실측.
    · 공간장: surge=관측소 IDW, sealevel=`maxele.63` 셀평균×시간 envelope, wind=`fort.22` 트랙 Rankine. (각 frames=times)
  - Phase4~5: `post_to_agent.sh 2024_09_JONGDARI` → decision/report 생성. JONGDARI는 약한 열대폭풍이라 최고등급 정상·위험관측소 0(정상 동작).
  - **검증**: healthz 케이스 2건(JONGDARI, NARITEST). 외부 IP 200 — `/scenario/2024_09_JONGDARI`, `/api/scenario|timeseries|field(surge/wind)`, `/case`, `/report`. 인천 시계열 −443.5~417.5cm(서해 대조차 실측 규모), 최대해일고 53.2cm=파일3 일치. NARITEST 회귀 없음. 기존 server.py/scenario.html 무수정.
- 막힘 → 해결: loc.dat DT_ID가 stations.json과 5건 불일치 → 정찰에서 좌표/코드 기반 크로스워크 도출(안흥 0034→0067, 위도 0030→0068, 마산 0015→0062, 포항 0009→0091), 흑산도는 thresholds 없이 캐리. 시간축은 폴더명(KST 런시각) 대신 fort.15/fort.22 UTC 사용.
- 접속: http://192.168.2.83:8787/scenario/2024_09_JONGDARI

### [#12] JONGDARI 케이스 데이터 출처 검토(실측 vs 합성) — 원본 대조
- 작성자(팀원): MS (C팀 팀장)
- 목표: 대시보드 JONGDARI 케이스가 실제로 실측 데이터로 표출되는지 원본 파일과 교차검증.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "실제 데이터로 표출한건지 검토"
- 사용한 기법(있으면): (b) 외부 데이터 연동 — 어댑터 코드 정독 + 원본 fort.61/3.MAX_surge/maxele 값 직접 대조
- 결과(부분 실측으로 판정):
  - 실측 확인: 해수위 시계열(`fort.61`×100, 인천 349.3/389.9·부산 −61.7 정확 일치), 관측소 최대해일고+첨두(`3.MAX_surge`, 인천 53.3·부산 7.4), 태풍 트랙(`fort.22` ATCF), 해수위 공간장 공간패턴(`maxele.63`).
  - 합성/근사(실측 아님): **해일고 시계열(가우시안 bump — 첨두값/시각만 실측)**, 천문조 점선(total−bump), 해일고 공간장(IDW), 바람장(Rankine 합성), 해수위 공간장 시간변화(엔벨로프), 통보문/강풍반경.
  - maxele 리샘플 일부 셀이 1500cm 클램프(육상/처오름 artifact).
  - **중요 발견**: 원본에 `Model/onlytide/fort.61`(천문조 360×33)·`onlytide/maxele.63`·`fort.74`(바람장)가 실재 → 해일고=총수위−천문조로 실측 계산 가능. 어댑터는 onlytide 없음으로 잘못 가정했음.
- 다음 단계(제안): 어댑터를 개선해 해일고 시계열=fort.61−onlytide/fort.61(실측), 천문조=onlytide/fort.61(실측), (선택) 바람장=fort.74, 해일고 공간장=maxele 차분 + 클램프 보정.
- 막힘 → 해결: 없음(검토).

### [#13] JONGDARI 케이스 전면 실측화 — 해일고=fort.63−onlytide, 모든 값 실측 반영
- 작성자(팀원): MS (C팀 팀장)
- 목표: #12에서 합성으로 드러난 부분(해일고 시계열·천문조·공간장·바람장)을 원본 ADCIRC 실측으로 전부 교체.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "해수위는 fort.63, onlytide가 조위만 fort.63 - onlytide의 fort.63 해야 해일고임 모든 값을 실제 데이터 반영해야함"
- 사용한 기법(있으면): (b) 외부 대용량 데이터 직접 처리 — fort.63/onlytide·fort.74(각 1~2GB) 스트리밍 1패스 파싱
- 결과(어댑터 `agent/ingest_model_output.py` 전면 재작성):
  - 헤더 확인: fort.63·onlytide/fort.63·fort.74 모두 60프레임 1시간 간격, 580,541노드, 동일 시작(262800s=2024-08-19 04:00Z) → 노드별·시각별 차분 가능.
  - **관측소 시계열(실측)**: 해수위=`fort.61`, 천문조=`onlytide/fort.61`, 해일고=`fort.61−onlytide/fort.61`. fort.63 시각에 정렬 샘플(60스텝).
  - **공간장(실측, 시변 60프레임, 24×24 리샘플, dry -99999 스킵)**: sealevel=`fort.63`, surge=`fort.63−onlytide/fort.63`(노드별 차분 후 셀평균), wind=`fort.74`(u,v 셀평균·speed).
  - 트랙=`fort.22`(기존 실측), 최대해일고/첨두=`3.MAX_surge`(실측).
  - **검증(원본 대조)**: 인천 해수위 389.9=fort.61×100, 천문조 389.9=onlytide×100, 해일고 0.0=차분(폭풍전 정상). surge 공간장 max 102.8/min −79.4(set-down 실측), wind max 23.9m/s. **기존 1500cm 클램프 artifact 제거**(dry 스킵). 스트리밍 ~1분.
  - 서버 재기동·Phase4 재생성, 외부 IP 전 엔드포인트 200.
- 막힘 → 해결: 대용량(1.1GB×2+1.9GB) → 두 fort.63를 lockstep 스트리밍하며 노드 차분을 격자에 누적(메모리 일정). cwd 리셋 대비 절대경로. 
- 유의(다음 다듬기): sealevel 공간장에 해안 처오름 노드가 최대 ~21.9m로 잡혀 색 스케일이 치우칠 수 있음 → 프론트 표출 시 분위수(예: 2~98%) 클램프 권장(데이터는 실측 유지).
- 접속: http://192.168.2.83:8787/scenario/2024_09_JONGDARI

### [#14] ADCIRC sample_run 자가치유 순환구조 — mpi.sh 거짓성공 진단 + 소넷 자동 fort.15 수정 루프
- 작성자(팀원): MS (C팀 팀장)
- 목표: `sample_run`의 `mpi.sh`를 돌려보고 진짜 완주를 판정, 실패면 순환구조로 원인을 파악하며 `fort.15`만 고쳐 끝까지 완주시키기(수정 판단은 루프 안 소넷, 회당 사용자 승인, v53 매뉴얼 근거).
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "mpi.sh 수행후 제대로 수행했다면 넘어가고 제대로 수행되어있지 않으면 클로드코드 cli로 소넷모델을 활용해서 fort.15 만 수정 … 순환구조 스크립트를 만들어서 원인을 파악하면서 수행을 끝까지 완료 … adcirc 공식 사용자 매뉴얼 v53 참조 … 최적 순환구조를 만들어 ultracode 실행하고 애매한것은 딥인터뷰 실행"
- 사용한 기법: (a) 서브에이전트 — Plan 에이전트로 루프·샌드박스 설계 / (b) 딥인터뷰(AskUserQuestion 6문)로 성공게이트·수정범위·반복정책·AI설정 확정 / (c) 루프 내 소넷 헤드리스(`claude -p --model claude-sonnet-4-6`)가 진단·수정 / (d) v53 공식매뉴얼 WebFetch 근거.
- 진단(선행): `mpi.sh`는 ① ADCIRC가 `ErrorElev` 발산으로 자기중단해도 `MPI terminated with Status=0`을 찍어 **거짓 성공** 통과, ② `./padcirc > log.dat`로 **stderr 미포착**(rank0 아닌 PE의 발산 메시지 누락). 판단은 소넷에 위임.
- 결과(산출물 `automation/self_heal_adcirc.sh`):
  - 4중 성공게이트: ①MPI Status=0 ②stdout+stderr 양쪽 무발산(ErrorElev/NaN/Elevation.gt) ③RNDAY 완주(last_ts×|DT|≥RNDAY) ④maxele.63 생성·유한. (mpi.sh의 단일 grep 거짓성공 차단)
  - 실패분류(수정판단 없음): ADCPREP_FAIL/RUN_TIMEOUT/MPI_ABORT(환경→소넷 미호출) · NODAL_ATTR_NOT_FOUND/ELEV_BLOWUP/NAN/DID_NOT_REACH_RNDAY/NO_MAXELE(→소넷). 로그발췌+현 파라미터를 컨텍스트로 패키징.
  - 소넷 샌드박스: 프롬프트 stdin 전달(가변인자 플래그가 위치인자 삼키는 버그 회피), `acceptEdits`+`--disallowedTools Bash Write`, 쓰기는 fort.15만. 권위 보증은 **해시가드+check_scope**(허용줄 L14/15·21/22/26/27만 변경, RNDAY L25 불변, 그 외 변경 시 백업복원).
  - 회당 수동승인: `run`(1사이클→실패시 소넷수정 적용→diff제시→정지)/`approve`(다음 사이클)/`revert`(복원). 안전장치: mpirun timeout(MAX_WALL), MAX_ITER, 노드 소프트프로브.
  - 검증: 스크래치 격리테스트로 소넷 헤드리스가 대상파일만 편집(타 파일 불변) 확인. 본 cycle 실행은 사용자 승인 게이트로 진행 중.
- 막힘 → 해결: (1) `set -u`에서 oneAPI setvars.sh source가 미정의변수로 셸 즉시종료(exit1) → source 구간만 `set +u` 래핑. (2) `claude -p` 위치인자 프롬프트가 `--disallowedTools` 가변인자에 흡수 → stdin 전달로 해결.
- 경로: `geosr-hackathon-kit/automation/self_heal_adcirc.sh` (로그/백업 `automation/logs/selfheal/<세션>/`). 대상 `sample_run/fort.15`(소넷 유일 편집), 참조 fort.13/14·machine·mpi.sh.

### [#15] ...
(필요한 만큼 계속 추가)

---

## 마무리 요약 (1~2줄)
- 가장 효과적이었던 에이전트 활용법:
- 다른 팀이 그대로 따라 하려면 필요한 것:
