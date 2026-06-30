# C팀 통합 자동화 시스템 — 상세 개발 계획서

> 작성자: 박지민 (JM) | 최종 갱신: 2026-06-30

---

## 전체 파이프라인 흐름

```
[기상청 태풍 통보문]
       ↓ DATA_DIR 수신
[Phase 1] 신규 케이스 감시         check_typhoon.sh  ← ✅ 완료
       ↓ 자동 트리거
[Phase 2] 수치모형 수행             run_pipeline.sh   ← ✅ 완료 (DRY_RUN 검증)
   01_pre → 02_model(padcirc) → 03_tide → 04_post
       ↓ maxele.63 / FigureGen 산출물
[Phase 3] 가시화 결과 정리·전달    post_to_agent.sh  ← 🔴 미구현 (JM 담당)
       ↓ GeoTIFF + 침수통계 CSV
[Phase 4] AI 의사결정 에이전트     ai_decision.py    ← 🔴 미구현 (JM 담당)
       ↓ 위험도 판단 JSON
[Phase 5] 보고서 자동 작성         generate_report.py← 🔴 미구현 (JM 담당)
       ↓
[의사결정 보고서 완성]
```

---

## Phase 1 — 태풍 통보문 감시 ✅ 완료

| 항목 | 내용 | 상태 | 파일 |
|------|------|:----:|------|
| crontab 5분 주기 신규 케이스 감지 | `DATA_DIR` 하위 `2*` 폴더 탐색 | ✅ | `check_typhoon.sh` |
| 중복 수행 방지 | 처리완료 케이스 영속 상태파일 누적 | ✅ | `automation_state/processed_cases.txt` |
| 실패 시 다음 주기 재시도 | rc≠0이면 상태파일 미기록 | ✅ | `check_typhoon.sh` |
| KMA 통보문 수신 경로 연결 | `DATA_DIR` 환경변수 설정 | 🔴 수작업(1회) | crontab 등록 시 지정 |
| 가상태풍 테스트베드 | NARITEST (제주→경남→동해, 2.5일) | ✅ | `typhoon.in` (서버) |

---

## Phase 2 — 수치모형 수행 ✅ 완료 (DRY_RUN)

| 항목 | 내용 | 상태 | 파일 |
|------|------|:----:|------|
| 01_PRE 전처리 | 바람장·hotstart·조화분조 생성 | ✅ | `01_runp_pre.csh` |
| 02_MODEL padcirc 본수행 | adcprep(--partmesh→--prepall) + mpirun padcirc | ✅ | `02_runp_model_padcirc.csh` |
| 03_TIDE 조위 수행 | 폭풍해일 산출용 조위 단독 수행 | ✅ | `03_runp_onlytide.csh` |
| 04_POST FigureGen 가시화 | 침수범위·최대수위 이미지 자동 생성 | ✅ | `04_runp_post.csh` |
| 오케스트레이터 (자동) | 01→02→03→04 순서 자동 수행 | ✅ | `run_pipeline.sh` |
| 수동 순차 수행기 | 단계별 확인하며 수동 실행 | ✅ | `run_manual.sh` |
| 코어 수 가변 | 스크립트 인자로 NP 지정 (기본 120) | ✅ | `02_runp_model_padcirc.csh` |
| **[버그]** `run_pipeline.sh` 모델 스크립트 | `02_runp_model.csh`(padcswan) 호출 중 → padcirc로 수정 필요 | 🟡 수정 필요 | `run_pipeline.sh` L85 |
| MPI 클러스터 실제 수행 | wave01~28 노드, 240~480코어 권장 (109만 노드 격자) | 🔴 수작업 | 서버 직접 실행 |

### Phase 2 수행 환경 요약

| 항목 | 값 |
|------|----|
| 모델 | padcirc (ADCIRC 단독, SWAN 미연동) |
| 격자 | `fort.14` — 1,091,756 노드 / 580,541 요소 (G_100m_utm_msl) |
| 권장 코어 | 240~480코어 (노드당 60코어 기준 4~8노드) |
| 예상 수행시간 | 3일 모의 기준 약 3~5시간 (240코어) |

---

## Phase 3 — 가시화 결과 정리·전달 🔴 미구현 (JM 담당)

> **목표**: 04_post 완료 즉시 산출물을 자동 정리하고 AI 에이전트 입력으로 전달한다.

### 입력 / 출력

| 구분 | 내용 |
|------|------|
| 입력 | `maxele.63` (최대수위), FigureGen 이미지(PNG), 시계열 추출 결과 |
| 출력 | GeoTIFF (`maxele.tif`), 침수통계 CSV, AI 입력 폴더 |

### 상세 개발 항목

| # | 개발 항목 | 구현 방법 | 산출물 | 우선순위 |
|---|-----------|-----------|--------|:--------:|
| 3-1 | `run_pipeline.sh` padcirc 버그 수정 | L85 `02_runp_model.csh` → `02_runp_model_padcirc.csh` 변경 | `run_pipeline.sh` | 🔥 즉시 |
| 3-2 | GeoTIFF 변환 자동화 | `make_tif_path_no.py` 호출 스크립트 래핑 | `maxele.tif` | 1순위 |
| 3-3 | 침수 통계 추출 | `Model_Data_Read_Ch_data.py` 호출 → 침수면적·최대수위·영향지역 CSV | `flood_stats.csv` | 1순위 |
| 3-4 | AI 입력 폴더 전달 | `scp_to_ai.sh` 수정 (현재 미연동) → 케이스별 결과 폴더 구성 | `agent_input/{CASE}/` | 1순위 |
| 3-5 | `post_to_agent.sh` 통합 스크립트 작성 | 3-2~3-4를 순서대로 호출하는 wrapper | `automation/post_to_agent.sh` | 1순위 |
| 3-6 | `run_pipeline.sh`에 Phase 3 연결 | 04_post 완료 후 `post_to_agent.sh` 자동 호출 추가 | `run_pipeline.sh` | 2순위 |

---

## Phase 4 — AI 의사결정 에이전트 🔴 미구현 (JM 담당)

> **목표**: Phase 3 산출물(이미지 + 통계)을 Claude API에 입력해 위험도를 자동 판단한다.

### 입력 / 출력

| 구분 | 내용 |
|------|------|
| 입력 | `maxele.tif`, `flood_stats.csv`, FigureGen PNG, 태풍 케이스명 |
| 출력 | `decision.json` (위험도 등급·근거·권고사항) |

### 상세 개발 항목

| # | 개발 항목 | 구현 방법 | 산출물 | 우선순위 |
|---|-----------|-----------|--------|:--------:|
| 4-1 | 위험도 판단 기준 정의 | 예보관 기준으로 임계값 정의 (침수면적·최대수위·영향지역별 등급) | `risk_criteria.json` | 1순위 |
| 4-2 | Claude API 연동 에이전트 | `anthropic` Python SDK + vision으로 FigureGen 이미지 분석 | `automation/ai_decision.py` | 1순위 |
| 4-3 | 위험도 판단 프롬프트 작성 | 통계 CSV + 이미지 + 임계값 → 위험도 등급(관심/주의/경계/심각) 판단 | `assets/prompts/decision_prompt.md` | 1순위 |
| 4-4 | 판단 결과 구조화 | JSON 출력: 위험도 등급, 근거 문장, 영향 지역, 권고 조치 | `agent_input/{CASE}/decision.json` | 2순위 |
| 4-5 | `post_to_agent.sh`에서 자동 호출 | Phase 3 완료 후 `ai_decision.py` 자동 실행 | `run_pipeline.sh` 연결 | 2순위 |

---

## Phase 5 — 보고서 자동 작성 🔴 미구현 (JM 담당)

> **목표**: Phase 4 위험도 판단 결과를 바탕으로 예보관이 바로 사용할 수 있는 보고서를 자동 생성한다.

### 입력 / 출력

| 구분 | 내용 |
|------|------|
| 입력 | `decision.json`, FigureGen PNG, `flood_stats.csv`, 태풍 메타정보 |
| 출력 | 의사결정 보고서 (`report_{CASE}.md` → PDF 변환 선택) |

### 상세 개발 항목

| # | 개발 항목 | 구현 방법 | 산출물 | 우선순위 |
|---|-----------|-----------|--------|:--------:|
| 5-1 | 보고서 템플릿 작성 | 예보관 실사용 양식 기반 마크다운 템플릿 | `assets/report_template.md` | 1순위 |
| 5-2 | 보고서 자동 생성 스크립트 | Claude API로 템플릿 + 판단 결과 → 완성 보고서 | `automation/generate_report.py` | 1순위 |
| 5-3 | 이미지 삽입 | FigureGen PNG를 보고서 내 자동 첨부 | 보고서 내 이미지 섹션 | 2순위 |
| 5-4 | 보고서 배포 | 완성 보고서를 공유 경로에 자동 저장 (선택: 이메일 발송) | `output/{CASE}/report_{CASE}.md` | 2순위 |
| 5-5 | `run_pipeline.sh`에 최종 연결 | Phase 5까지 완전 자동화 파이프라인 완성 | `run_pipeline.sh` 전체 통합 | 3순위 |

---

## 전체 작업 우선순위

```
🔥 즉시  → [3-1] run_pipeline.sh padcirc 버그 수정
1순위    → [3-2~3-5] post_to_agent.sh 구현 (가시화→AI 전달)
         → [4-1~4-3] ai_decision.py 구현 (위험도 판단)
         → [5-1~5-2] generate_report.py 구현 (보고서 생성)
2순위    → [3-6, 4-4~4-5, 5-3~5-4] 파이프라인 자동 연결
3순위    → [5-5] 전체 DRY_RUN 통합 테스트
```

---

## JM 담당 산출물 목록

| 파일 | 설명 |
|------|------|
| `automation/run_pipeline.sh` | padcirc 버그 수정 |
| `automation/post_to_agent.sh` | Phase 3 결과 정리·전달 스크립트 |
| `automation/ai_decision.py` | Phase 4 Claude API 위험도 판단 에이전트 |
| `automation/generate_report.py` | Phase 5 보고서 자동 작성 스크립트 |
| `assets/prompts/decision_prompt.md` | 위험도 판단 프롬프트 |
| `assets/report_template.md` | 보고서 템플릿 |
