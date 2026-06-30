# PROCESS_LOG — 작업 기록 (과정 70점의 핵심 근거)

> 표준 헤더(CLAUDE.md 등)를 로드했다면 에이전트가 알아서 채워 줍니다. 비면 직접 채우세요.
> 원칙: **실제로 시킨 프롬프트를 그대로 인용**할 것. 요약만 있으면 점수가 깎입니다.

## 작성자 정보 (개인별 로그 — 본인 것만)
- 팀명: C팀 (teamC)
- 본인 이름(작성자): 박지민 (Park Jimin)
- 공통과제(우리 팀이 자동화한 반복 수작업): _(작업 중 채울 예정)_
- 내가 맡은 부분: 팀원
- 자유과제(있으면): _(미정)_

> **이 로그는 본인 것만 작성**합니다. 각자 자기 PC·계정으로 작업해 개인 로그를 남기고, 제출 시 **영문 파일명** `teamC_parkjimin_PROCESS_LOG.md`로 저장하세요. **한글 파일명은 압축 시 깨지므로 금지** — 한글 팀명·이름은 위 '작성자 정보'에 적습니다.

## 효과 측정 (Before → After, 결과 ⑥ 채점용 — 형식 자유)
> **지표는 자기 업무에 맞게 고름 — 강제 항목 없음.**

| 지표(자기 업무에 맞게) | Before(기존 수작업) | After(에이전트화) |
|------|------|------|
|  |  |  |
|  |  |  |

## 사용 기법 (권장·가점, 필수 아님)
- [ ] (a) 서브에이전트 / 역할 분담
- [ ] (b) 외부 도구·데이터 연동 (파일/API/MCP/사내데이터)
- [ ] (c) 재사용 산출물 (스킬 / 프롬프트셋 / CLAUDE.md / 서브에이전트 구성)

---

## 작업 로그 (단계마다 1개씩 누적 / 시간순)

### [#1] PROCESS_LOG 파일 생성 및 작업 환경 세팅
- 작성자(팀원): 박지민
- 목표: 개인 작업 로그 파일을 생성하고 이후 모든 작업 기록을 이 파일에 남긴다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "이제 여기서 나오는 모든 작업 로그는 이 파일에 기록하고 저장해줘 /home/jmpark/work/geosr_hackathon/geosr-hackathon-kit-team-c/submit/PROCESS_LOG_team_c_JM.md"
- 사용한 기법(있으면): -
- 결과: 개인 PROCESS_LOG 파일 생성 완료. 이후 작업부터 이 파일에 자동 기록.
- 막힘 → 해결: -

---

### [#2] 통합 자동화 시스템 작업 계획서 작성
- 작성자(팀원): 박지민
- 목표: Phase별 자동화 현황(완료/수작업/미구현)을 구분하고 JM 담당 파트를 명확히 정의한다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "이 phase가 하나의 자동화 시스템으로 만들어져야해, 여기서 수작업이 들어가는 부분, 자동화 되어있는 부분을 구별해서 계획서를 만들어봐"
  > "작업 계획 md 를 geosr-hackathon-kit-team-c 에 _JM.md 로 만들어줘"
- 사용한 기법(있으면): (b) 도구연동 — check_typhoon.sh, run_pipeline.sh, automation/README.md, PROCESS_LOG_team_c_SY.md 분석
- 결과:
  - `WORK_PLAN_JM.md` 생성 — Phase 1~5 자동화 현황 표, 즉시 수정 가능한 버그(run_pipeline.sh padcirc 미연결), 우선순위 작업 순서 정리
  - JM 담당 파트 확정: Phase 3~5 (가시화→에이전트→보고서) 구현
- 막힘 → 해결: -

---

### [#3] Phase별 상세 개발 계획서 작성 (WORK_PLAN_JM.md 갱신)
- 작성자(팀원): 박지민
- 목표: SY 팀원의 최신 작업(가상태풍 테스트베드, 격자 정정, run_manual.sh)을 반영해 Phase 1~5 전체의 자동화 현황과 JM 담당 상세 구현 계획을 표로 정리한다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "이제 phase 별로 상세 개발 계획 내용을 표로 정리하고 PLAN_JM.md 에 갱신해줘"
- 사용한 기법(있으면): (b) 도구연동 — run_manual.sh, PROCESS_LOG_team_c_SY.md(#5 가상태풍), automation/README.md 분석
- 결과:
  - `WORK_PLAN_JM.md` 갱신: Phase 1~5 전체 흐름도 + 각 Phase별 상세 개발 항목 표 작성
  - JM 담당 Phase 3~5 구현 계획 확정: post_to_agent.sh / ai_decision.py / generate_report.py
  - [버그] run_pipeline.sh L85 padcirc 미연결 → 즉시 수정 대상으로 명시
  - 전체 우선순위(🔥 즉시 → 1~3순위) 정리
- 막힘 → 해결: -

---

### [#4] Work Plan 전면 재작성 — 전체 계획 + Phase별 세부 개발 내용 표
- 작성자(팀원): 박지민
- 목표: 팀 전체 관점의 Work Plan을 담당자 없이 정리하고, Phase 1~5 각각의 세부 개발 항목·구현방식·의존성·산출물을 표로 작성한다.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "지금 당장 담당을 만들지 말고, 전체적인 work plan 이 필요해"
  > "응 저장하고, 각 phase 별로 세부 개발내용 표로 정리해줘"
- 사용한 기법(있으면): (b) 도구연동 — patch_notice_backup_path.sh, setup_run.sh, PROCESS_LOG_team_c_SY.md #6 최신 작업 반영
- 결과:
  - `WORK_PLAN_JM.md` 전면 재작성: 전체 Work Plan 표(순번 1~15) + 일정 + Phase 1~5 세부 개발 항목 표
  - Phase 2에 setup_run.sh·patch_notice_backup_path.sh 반영, 격자 1,091,756 노드 기준 수정
  - Phase 3~5 세부 항목 (입출력·구현방식·의존성·산출물) 체계화
- 막힘 → 해결: -

---

---

### [#1] Phase 5 보고서 자동 작성 — 상세 개발 명세 작성
- 작성자(팀원): 박지민 (JM)
- 목표: 태풍 통보문별 보고서 자동 생성(generate_report.py) 구현 설계 문서 작성. 조위관측소 극치해면 시계열 필수 포함.
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "이제 내가 할 작업은 모델 결과를 가지고 태풍 통보문 별 보고서 자동 작성 구현을 해야해. 참고 자료는 /home/jmpark/work/geosr_hackathon/data 내부의 pdf에 있는 걸 참고해 조위관측소 극치해면 자료가 시계열로 무조건 들어가야해. 이걸 가지고 이 작업 부분들의 상세 개발 내용을 표로 만들어주고, md 자료 만들어줘"
- 사용한 기법(있으면): (b) 도구연동 — PDF 참고문서 Read, 기존 automation/ 스크립트 분석
- 결과: `PHASE5_REPORT_DEV.md` 생성. 개발 항목 10개 표, 조위관측소 극치해면 시계열 그래프 코드 스케치, 보고서 템플릿(Jinja2), generate_report.py 처리 흐름, Claude API 프롬프트 설계 포함.
- 막힘 → 해결: 없음

---

## 마무리 요약 (1~2줄)
- 가장 효과적이었던 에이전트 활용법:
- 다른 팀이 그대로 따라 하려면 필요한 것:

---
### [#3] 보고서 표준 포맷(draft_10 기반) HWPX 템플릿 및 변수 정의서 작성
- 작성자(팀원): 박지민 (JM)
- 목표: 태풍 통보문 발행 → 모델 수행 → 결과파일 → 보고서 → 가시화 사이트 연계 과정에서, 매번 동일 포맷으로 자동 생성되는 HWPX 보고서 템플릿 구축
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "10번 으로 만들건데, 포맷을 먼저 만들어줘. 태풍 통보문 발행 > 모델 수행 및 결과 > 결과파일로 보고서 작성 > 가시화 사이트에서 다운로드 가능하게 연계 이런 과정으로 갈건데 매번 결과가 나오면 동일 포맷으로 만들 수 있게, 필요한 그림, 내용에 대한 {그림1} {위험도} 이런 변수들을 넣어서 10번에 대한 보고서 포맷을 만들어"
- 사용한 기법(있으면): (b) 도구연동 — geosr-hwpx-main YeoboBuilder / yebobu_builder.py
- 결과:
  - `CLAUDE/hwpx_output/REPORT_TEMPLATE.hwpx` — 변수 「」 표기가 삽입된 표준 포맷 HWPX (9개 섹션)
  - `CLAUDE/REPORT_VARIABLES.md` — 전체 변수(총 50여개) 정의·소스·예시 정리
  - `CLAUDE/build_report_template.py` — 템플릿 HWPX 빌드 스크립트
  - 변수 범주: 태풍 메타(typhoon.in) / 관측소 결과(MAX_SURGE_STATION.OUT) / 시계열 그림(*_surge.out) / FigureGen 분포도 / 침수 통계(maxele.63) / AI 위험도·권고사항(Claude API)
- 막힘 → 해결(있었다면): 없음
---

---
### [#4] 가상 태풍 opersys (자동화 파이프라인) 구현 및 실행
- 작성자(팀원): 박지민 (JM)
- 목표: JONGDARI 실결과 파일 기반 가상 태풍 데이터 생성 + 보고서 자동 작성 파이프라인 구현 및 실행
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "/data1/syjeong/2026/Inundation/02_Hackathon/00_Ref/01_Model_Output/2024_09_JONGDARI_202408201600_west/Model 예시 결과 파일이 여기 있어. 이걸 바탕으로 가상의 태풍 데이터를 만들어 보고서를 생성하는 opersys 만들어. 표출 스크립트들과 보고서 결과 및 생산 그림파일, csv 파일들도 전부 저장되게끔 만들어봐"
- 사용한 기법(있으면): (b) 도구연동 — JONGDARI 실결과(MAX_SURGE_STATION.OUT, *_surge.out) / geosr-hwpx-main YeoboBuilder
- 결과:
  - `opersys.py` — 4단계 파이프라인 오케스트레이터 (15.8초 완료)
  - `step1_gen_fake_data.py` — JONGDARI 기반 가상 데이터 생성 (스케일 교란 ±20%, 시드 고정) → CSV 37개
  - `step2_plot_risk_map.py` — 관측소 위험등급 지도 (빨강/주황/노랑/초록) → risk_map.png
  - `step3_plot_surge_ts.py` — 전 33개소 개별 시계열 + 권역별 패널 + 전체 멀티패널 → PNG 39개
  - `step4_generate_report.py` — HWPX 보고서 자동 생성 (그림 삽입 포함) → 3.5 MB
  - 출력 위치: `CLAUDE/post/2026_01_FAKETY_202606240000_west/`
- 막힘 → 해결(있었다면): 한글 폰트 없음 → NanumGothic(/usr/share/fonts) 적용 / ref_entry 인덱스 오류 수정 / math import 위치 수정
---

---
### [#5] GitHub pull 및 머지 충돌 해결
- 작성자(팀원): 박지민 (JM)
- 목표: 팀원(SY) 작업 내용을 로컬에 동기화, timestamps.txt 충돌 해결
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "깃헙에서 pull 해줘"
- 사용한 기법(있으면): -
- 결과:
  - `submit/evidence/timestamps.txt` 머지 충돌 해결 (SY의 #8·#9 항목 + JM의 15:27 이후 항목을 시간순 병합)
  - `git pull origin main` → Already up-to-date 확인
- 막힘 → 해결(있었다면): `<<<<<<< Updated upstream` / `>>>>>>> Stashed changes` 충돌 → 양쪽 항목 시간순 수동 병합 후 `git add` 해결
---

---
### [#6] ADCIRC mpi.sh 수행 전 진단 우선순위 기준 정의
- 작성자(팀원): 박지민 (JM)
- 목표: `mpi.sh` 수행 전 에러를 우선순위 순서로 빠르게 확인하는 진단 체계 설계
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "mpi.sh을 수행할때 확인할때 어떤 에러부터 확인할지 우선순위를 주고싶어. 1.입력자료 정상적인지 2.CFL조건이 정상적인지 3.바람장과 입력자료의 모의기간이 동일한지 등등에 대한 판별 range를 줄거야. fort.15에서 확인해서 판별할 점이 있으면 추천해줘"
- 사용한 기법(있으면): -
- 결과: 아래 6단계 우선순위 체계 확정
  - **P1-a** 필수파일 존재: `adcprep`, `padcirc`(실행권한), `fort.14`, `fort.15`, `machine`
  - **P1-b** NP 일관성: `mpi.sh -n` == `adcprep --np` == machine 슬롯수 3자 일치
  - **P2** fort.15 가변 파라미터: `RNDAY > DRAMP`, `DT > 0`, `STATIM` (IHOT 연계), `IHOT` 값 유효성
  - **P3** 조건부 필수파일: NWS→fort.22, NWP→fort.13(속성명 일치), IHOT→fort.67/68
  - **P4** 바람장–모의기간 일치: fort.22 첫/마지막 트랙 시각이 `STATIM ~ STATIM+RNDAY` 커버
  - **P5** CFL 안정성: `C = sqrt(g×h_max)×DT/dx_min ≤ 4` 격자별 권고 DT 표 작성
  - **P6** Hotstart 타임스탬프 일치 (IHOT>0만): fort.67/68 마지막 타임스탬프 == `STATIM`
- 막힘 → 해결(있었다면):
  - G·NFOVER는 고정값이므로 P2에서 제외 (사용자 피드백)
  - machine 체크 시 mpi.sh NP도 함께 확인해야 함 → P1-b로 분리 (사용자 피드백)
  - H0은 수행마다 변경 없음 → P2에서 제외
  - NSPOOLE은 hotstart 타임스탬프 일치 여부만 확인 → P6으로 축소
---

---
### [#7] ADCIRC mpi.sh 진단 우선순위 MD 문서 작성
- 작성자(팀원): 박지민 (JM)
- 목표: 확정된 P1-a ~ P6 우선순위를 참조 문서로 작성 (`automation/CHECK_PRIORITY.md`)
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "그럼 이제 우선순위 md 만들어봐"
- 사용한 기법(있으면): -
- 결과:
  - `automation/CHECK_PRIORITY.md` 생성
  - P1-a (필수파일 존재), P1-b (NP 일관성), P2 (fort.15 가변 파라미터), P3 (조건부 필수파일), P4 (바람장–모의기간 일치), P5 (CFL 안정성), P6 (Hotstart 타임스탬프) 각 항목별 판정 기준·실패 시 결과·확인 방법 포함
  - 진단 흐름 요약 다이어그램 포함
- 막힘 → 해결(있었다면): 없음
---

---
### [#7-1] CHECK_PRIORITY.md 세부 조정 (P5↔P6 교체·CFL 조건 추가·병렬 흐름 전환)
- 작성자(팀원): 박지민 (JM)
- 목표: 우선순위 MD를 실무 피드백 반영하여 3차 수정
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "우선순위 md 에서 P5랑 P6 순서를 바꿔줘"
  > "그리고 DT를 100으로 만들어서 수행했는데, 터졌어. DT 수정하고 다시 수행하는 걸 해보고싶은데, 어떤식으로 DT 수정하고 수행할거야?"
  > "CFL조건이 무조건 0보다 커야한다는 조건도 넣어줘"
  > "수행전에 모든 조건을 병렬로 진단하도록 흐름 요약 수정해줘"
- 사용한 기법(있으면): -
- 결과:
  - **P5↔P6 교체**: Hotstart 타임스탬프 → P5, CFL 안정성 → P6 (CHECK_PRIORITY.md, CHECK_DEV_PLAN.md 양쪽 반영)
  - **CFL > 0 조건 추가**: `0 < C = sqrt(g×h_max)×DT/dx_min ≤ 4` — DT·h_max·dx_min 모두 양수 필수
  - **DT 이분탐색 전략 설계**: DT 터짐 감지 → DT÷2 반복 → fort.15 `! DT` 코멘트 anchor sed 수정 → PE???? 정리 후 재수행. MS `self_heal_adcirc.sh`(AI 판단)와 역할 분리하여 fast-path로 연계
  - **진단 흐름 병렬화**: P1-a~P6 전 항목 동시 실행 → 전체 결과 수집 후 일괄 판정. 우선순위 번호는 FAIL 발생 시 수정 순서로 재정의
- 막힘 → 해결(있었다면): 없음
---

---
### [#8] ADCIRC 진단 스크립트 Phase별 개발 계획서 작성
- 작성자(팀원): 박지민 (JM)
- 목표: CHECK_PRIORITY.md 기반으로 `check_run.py` 구현을 Phase 0~7로 분해한 개발 계획서 작성
- 에이전트에게 시킨 것(실제 프롬프트 핵심 인용):
  > "우선순위 md 를 활용해서 각 우선순위에 맞게 개발 내용 계획서를 phase 별로 표로 표출해봐"
- 사용한 기법(있으면): (c) 재사용산출물 — CHECK_PRIORITY.md 기반
- 결과:
  - `automation/CHECK_DEV_PLAN.md` 생성
  - Phase 0(기반 구조) ~ Phase 7(Hotstart 타임스탬프)까지 8단계 구성
  - 각 Phase별 목표·산출물 함수명·구현 내용·엣지케이스·완료 기준 명시
  - Phase 3(`parse_fort15`)이 P3~P6 전체의 핵심 의존성임을 식별
- 막힘 → 해결(있었다면): 없음
---
