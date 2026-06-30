# C팀 통합 자동화 시스템 — Work Plan

> C팀: 태풍 발생부터 의사결정 보고서 작성까지 전 과정 자동화
> 기간: 2026-06-30 ~ 07-01 | 최종 갱신: 2026-06-30

---

## 1. 파이프라인 전체 흐름

```
[기상청 태풍 통보문]
        ↓ DATA_DIR 수신
  Phase 1 : 신규 케이스 감시        check_typhoon.sh  ✅ 완료
        ↓ 자동 트리거
  Phase 2 : 수치모형 수행            run_pipeline.sh   ✅ 완료
    01_pre → 02_model(padcirc) → 03_tide → 04_post
        ↓ maxele.63 / FigureGen 이미지
  Phase 3 : 가시화 결과 정리·전달   post_to_agent.sh  🔴 미구현
        ↓ GeoTIFF + 침수통계 CSV
  Phase 4 : AI 위험도 판단          ai_decision.py    🔴 미구현
        ↓ decision.json
  Phase 5 : 보고서 자동 작성        generate_report.py🔴 미구현
        ↓
  [의사결정 보고서 완성]
```

---

## 2. 전체 Work Plan

| 순번 | Phase | 작업 항목 | 입력 | 출력 | 구분 | 완료 기준 |
|:---:|:---:|-----------|------|------|:----:|-----------|
| 1 | 2 | `run_pipeline.sh` padcirc 버그 수정 | - | `run_pipeline.sh` | 버그 수정 | DRY_RUN에서 `02_runp_model_padcirc.csh` 호출 확인 |
| 2 | 1 | KMA 통보문 수신 경로 환경변수 설정 | 실제 DATA_DIR 경로 | crontab 등록 | 환경 설정 | `check_typhoon.sh` 실행 시 신규 케이스 감지 |
| 3 | 2 | 가상태풍(NARITEST) DRY_RUN 전체 흐름 검증 | `typhoon.in` | 단계별 로그 | 검증 | 01→02→03→04 오류 없이 완주 |
| 4 | 3 | GeoTIFF 변환 자동화 | `maxele.63` | `maxele.tif` | 신규 개발 | TIF 파일 정상 생성 |
| 5 | 3 | 침수 통계 자동 추출 | `maxele.63` | `flood_stats.csv` | 신규 개발 | 침수면적·최대수위·영향지역 수치 추출 |
| 6 | 3 | AI 입력 폴더 구성·전달 스크립트 | 이미지·CSV | `agent_input/{CASE}/` | 신규 개발 | 케이스별 폴더 자동 생성 및 파일 이동 |
| 7 | 3 | `post_to_agent.sh` 통합 wrapper 작성 | 4~6번 결과 | 전달 완료 | 신규 개발 | 04_post 완료 시 자동 실행 |
| 8 | 4 | 위험도 판단 기준 정의 | 예보관 기준 | `risk_criteria.json` | 기획 | 관심/주의/경계/심각 임계값 문서화 |
| 9 | 4 | Claude API 위험도 판단 에이전트 | 이미지·CSV·임계값 | `decision.json` | 신규 개발 | 위험도 등급·근거·권고사항 JSON 출력 |
| 10 | 4 | 위험도 판단 프롬프트 작성·검증 | 통계·이미지 | 정확한 등급 판단 | 프롬프트 | 테스트 케이스 3건 이상 검증 |
| 11 | 5 | 보고서 템플릿 작성 | 예보관 실사용 양식 | `report_template.md` | 기획 | 현업 양식과 일치 확인 |
| 12 | 5 | 보고서 자동 생성 스크립트 | `decision.json`·이미지 | `report_{CASE}.md` | 신규 개발 | 보고서 초안 자동 생성 |
| 13 | 5 | 보고서 공유 경로 자동 저장 | 완성 보고서 | `output/{CASE}/` | 신규 개발 | 지정 경로에 파일 저장 확인 |
| 14 | 전체 | Phase 1~5 통합 DRY_RUN 테스트 | 가상태풍(NARITEST) | 전체 로그·보고서 | 통합 검증 | 통보문 수신부터 보고서까지 무중단 완주 |
| 15 | 전체 | 실 클러스터 본수행 (NARITEST) | MPI 환경, 240~480코어 | `maxele.63`·FigureGen 이미지 | 실 운영 검증 | 실제 산출물 정상 생성 확인 |

---

## 3. 일정

| 시간대 | 목표 작업 |
|--------|-----------|
| Day 1 오후 | 순번 1~3 완료 (버그 수정·환경 설정·DRY_RUN 검증) |
| Day 1 저녁 | 순번 4~7 완료 (Phase 3 구현) |
| Day 2 오전 | 순번 8~13 완료 (Phase 4~5 구현) |
| Day 2 오후 | 순번 14~15 완료 (통합 테스트·데모 준비) |

---

## 4. Phase별 세부 개발 내용

---

### Phase 1 — 태풍 통보문 감시 ✅ 완료

| # | 세부 항목 | 구현 방식 | 현재 상태 | 파일 |
|---|-----------|-----------|:---------:|------|
| 1-1 | crontab 5분 주기 신규 케이스 감지 | `DATA_DIR` 하위 `2*` 폴더 탐색 | ✅ 완료 | `check_typhoon.sh` |
| 1-2 | 중복 수행 방지 | 처리완료 케이스 영속 상태파일 누적 기록 | ✅ 완료 | `automation_state/processed_cases.txt` |
| 1-3 | 실패 시 자동 재시도 | rc≠0이면 상태파일 미기록 → 다음 주기 재실행 | ✅ 완료 | `check_typhoon.sh` |
| 1-4 | 파이프라인 자동 트리거 | 신규 케이스 감지 시 `run_pipeline.sh` 호출 | ✅ 완료 | `check_typhoon.sh` |
| 1-5 | KMA 수신 경로 연결 | `DATA_DIR` 환경변수를 실제 통보문 수신 폴더로 지정 | 🔴 수작업(1회) | crontab 등록 시 지정 |

---

### Phase 2 — 수치모형 수행 ✅ 완료 (DRY_RUN 검증)

**수행 환경**

| 항목 | 값 |
|------|----|
| 모델 | padcirc (ADCIRC 단독, SWAN 미연동) |
| 격자 | `fort.14` — 1,091,756 노드 / 580,541 요소 (G_100m_utm_msl, ICS=2) |
| 실행파일 | `build/` → `Model/` 복사 완료 (Intel oneAPI MPI 2021.5.1) |
| 권장 코어 | 240~480코어 (노드당 60코어 기준 4~8노드) |
| 예상 수행시간 | 3일 모의 기준 약 3~5시간 (240코어) |
| 가상 테스트베드 | NARITEST (제주 남서→경남 상륙→동해 약화, 2.5일 트랙) |

**세부 항목**

| # | 세부 항목 | 구현 방식 | 현재 상태 | 파일 |
|---|-----------|-----------|:---------:|------|
| 2-1 | 소스 복사 및 작업폴더 구성 | `SRC/` → `RUN/{CASE}/` 복사 | ✅ 완료 | `run_pipeline.sh` |
| 2-2 | 01_PRE 전처리 | 바람장·hotstart·조화분조 생성 (`aswip` 포함) | ✅ 완료 | `01_runp_pre.csh` |
| 2-3 | 02_MODEL padcirc 본수행 | `adcprep --partmesh → --prepall` + `mpirun padcirc` | ✅ 완료 | `02_runp_model_padcirc.csh` |
| 2-4 | 03_TIDE 조위 전용 수행 | 폭풍해일 산출용 조위 단독 수행 | ✅ 완료 | `03_runp_onlytide.csh` |
| 2-5 | 04_POST FigureGen 가시화 | 침수범위·최대수위 이미지 자동 생성 | ✅ 완료 | `04_runp_post.csh` |
| 2-6 | 오케스트레이터 (완전 자동) | crontab → 01→02→03→04 순서 자동 수행 | ✅ 완료 | `run_pipeline.sh` |
| 2-7 | 수동 순차 수행기 | 단계별 Enter 확인하며 수동 실행 (`-y`로 연속) | ✅ 완료 | `run_manual.sh` |
| 2-8 | 환경 셋업 스크립트 | 실행파일·격자파일 배치, 권한 설정 자동화 | ✅ 완료 | `setup_run.sh` |
| 2-9 | 전처리기 NOTICE_BACKUP 경로 패치 | 바이너리 내 하드코딩 경로를 같은 길이 문자열로 치환 | ✅ 완료 | `patch_notice_backup_path.sh` |
| 2-10 | **[버그]** `run_pipeline.sh` 모델 스크립트 | L85: `02_runp_model.csh`(padcswan) 호출 중 → padcirc로 수정 | 🟡 수정 필요 | `run_pipeline.sh` L85 |
| 2-11 | 클러스터 실제 본수행 | wave01~28 노드에서 MPI 실행 | 🔴 수작업 | 서버 직접 실행 |

---

### Phase 3 — 가시화 결과 정리·AI 전달 🔴 미구현

**입출력**

| 구분 | 내용 |
|------|------|
| 입력 | `maxele.63` (최대수위 NetCDF), FigureGen PNG 이미지, 시계열 추출 결과 |
| 출력 | `maxele.tif` (GeoTIFF), `flood_stats.csv` (침수통계), `agent_input/{CASE}/` (AI 입력 폴더) |

**세부 항목**

| # | 세부 항목 | 구현 방식 | 의존성 | 산출물 |
|---|-----------|-----------|--------|--------|
| 3-1 | GeoTIFF 변환 | `make_tif_path_no.py` 래핑 → `maxele.63` 읽어 GeoTIFF 생성 | Phase 2 완료 | `maxele.tif` |
| 3-2 | 침수 통계 추출 | `Model_Data_Read_Ch_data.py` 래핑 → 침수면적·최대수위·영향 행정구역 추출 | Phase 2 완료 | `flood_stats.csv` |
| 3-3 | FigureGen 이미지 수집 | `Post/` 디렉토리에서 PNG 파일 목록화 및 케이스 폴더로 복사 | 04_post 완료 | `images/*.png` |
| 3-4 | AI 입력 폴더 구성 | 케이스별 `agent_input/{CASE}/` 생성 후 TIF·CSV·PNG 배치 | 3-1~3-3 | `agent_input/{CASE}/` |
| 3-5 | `scp_to_ai.sh` 연동 | 기존 `scp_to_ai.sh` 수정하여 3-4 폴더를 AI 서버로 전송 | 3-4 | 전송 완료 로그 |
| 3-6 | `post_to_agent.sh` 통합 wrapper | 3-1~3-5를 순서대로 호출하는 단일 진입점 스크립트 | 3-1~3-5 | `automation/post_to_agent.sh` |
| 3-7 | `run_pipeline.sh`에 Phase 3 자동 연결 | 04_post 완료 직후 `post_to_agent.sh` 호출 추가 | 3-6 | `run_pipeline.sh` 수정 |

---

### Phase 4 — AI 위험도 판단 에이전트 🔴 미구현

**입출력**

| 구분 | 내용 |
|------|------|
| 입력 | `maxele.tif`, `flood_stats.csv`, FigureGen PNG, 태풍 케이스명, `risk_criteria.json` |
| 출력 | `decision.json` (위험도 등급·판단 근거·영향 지역·권고 조치) |

**세부 항목**

| # | 세부 항목 | 구현 방식 | 의존성 | 산출물 |
|---|-----------|-----------|--------|--------|
| 4-1 | 위험도 판단 기준 정의 | 예보관 기준으로 침수면적·최대수위별 관심/주의/경계/심각 임계값 정의 | 예보관 협의 | `risk_criteria.json` |
| 4-2 | 판단 프롬프트 작성 | 시스템 프롬프트: 역할·기준·출력 형식 / 유저 프롬프트: 통계·이미지 | 4-1 | `assets/prompts/decision_prompt.md` |
| 4-3 | Claude API vision 에이전트 구현 | `anthropic` Python SDK — 이미지(PNG) + 통계(CSV) 동시 입력, JSON 출력 강제 | 4-1, 4-2 | `automation/ai_decision.py` |
| 4-4 | 판단 결과 JSON 구조화 | 등급(관심/주의/경계/심각), 근거 문장, 영향 지역 리스트, 권고 조치 | 4-3 | `decision.json` |
| 4-5 | 프롬프트 검증 | 가상태풍(NARITEST) 기준으로 테스트 3건 이상 실행·결과 확인 | 4-3, 4-4 | 검증 로그 |
| 4-6 | `post_to_agent.sh`에서 자동 호출 | Phase 3 완료 후 `ai_decision.py` 자동 실행 추가 | 4-3 | `post_to_agent.sh` 수정 |

---

### Phase 5 — 보고서 자동 작성 🔴 미구현

**입출력**

| 구분 | 내용 |
|------|------|
| 입력 | `decision.json`, FigureGen PNG, `flood_stats.csv`, 태풍 메타정보(케이스명·일시) |
| 출력 | `report_{CASE}.md` (의사결정 보고서 초안, PDF 변환 선택) |

**세부 항목**

| # | 세부 항목 | 구현 방식 | 의존성 | 산출물 |
|---|-----------|-----------|--------|--------|
| 5-1 | 보고서 템플릿 작성 | 예보관 실사용 양식 기반 마크다운 — 태풍 개요·침수 통계·위험도 판단·권고사항·첨부 이미지 섹션 | 예보관 협의 | `assets/report_template.md` |
| 5-2 | 보고서 생성 프롬프트 작성 | 템플릿 + `decision.json` + 통계를 Claude API에 입력해 완성 보고서 초안 생성 | 5-1 | `assets/prompts/report_prompt.md` |
| 5-3 | 보고서 자동 생성 스크립트 | Claude API로 템플릿 채워 마크다운 보고서 생성 | 5-1, 5-2 | `automation/generate_report.py` |
| 5-4 | FigureGen 이미지 자동 첨부 | 보고서 내 지정 섹션에 PNG 경로 자동 삽입 | 5-3 | 보고서 내 이미지 섹션 |
| 5-5 | 보고서 공유 경로 저장 | 완성 보고서를 `output/{CASE}/report_{CASE}.md`로 자동 저장 | 5-3 | `output/{CASE}/report_{CASE}.md` |
| 5-6 | `generate_report.py` 파이프라인 연결 | Phase 4 완료 후 자동 호출 추가 | 5-3 | 파이프라인 완성 |
| 5-7 | 전체 통합 DRY_RUN 테스트 | NARITEST 기준 Phase 1~5 무중단 완주 확인 | 전체 | 통합 테스트 로그 |
