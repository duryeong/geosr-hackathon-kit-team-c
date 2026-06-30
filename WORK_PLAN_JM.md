# C팀 통합 자동화 시스템 작업 계획서

> 작성자: 박지민 (JM) | 작성일: 2026-06-30

---

## 프로젝트 목표

태풍 통보문 수신부터 의사결정 보고서 작성까지 **담당자 개입 없이 전 과정을 자동화**한다.

---

## 전체 흐름도

```
[기상청 태풍 통보문 수신]
         ↓  DATA_DIR 수신 경로 연결
[Phase 1] 신규 케이스 감시          check_typhoon.sh (crontab 5분)
         ↓  자동 트리거
[Phase 2] 수치모형 수행              run_pipeline.sh
   ├─ 01_pre    (바람장·hotstart·조위 전처리)
   ├─ 02_model  (padcirc 본수행 — MPI 클러스터)
   ├─ 03_tide   (조위 수행)
   └─ 04_post   (FigureGen 가시화)
         ↓  ← 현재 끊김
[Phase 3] 가시화 결과 정리·전달      ← 구현 필요
         ↓
[Phase 4] AI 의사결정 에이전트        ← 구현 필요
         ↓
[Phase 5] 보고서 자동 작성           ← 구현 필요
```

---

## Phase별 자동화 현황 및 작업 계획

| Phase | 단계 | 항목 | 상태 | 비고 |
|:---:|------|------|:----:|------|
| **1** | 태풍 통보문 감시 | crontab 5분 주기 신규케이스 감지 | ✅ 자동 | `check_typhoon.sh` |
| **1** | | 처리완료 케이스 중복방지·재시도 | ✅ 자동 | 영속 상태파일(`processed_cases.txt`) |
| **1** | | KMA 통보문 → DATA_DIR 수신 경로 연결 | 🔴 수작업 | 실제 통보문 수신 폴더 환경변수 설정 필요 |
| **1** | | crontab 최초 등록 | 🔴 수작업 (1회) | 서버 로그인 후 `crontab -e` |
| **2** | 수치모형 수행 | 01→02→03→04 단계 오케스트레이션 | ✅ 자동 | `run_pipeline.sh` |
| **2** | | DRY_RUN 흐름 검증 | ✅ 자동 | 클러스터 없이 검증 가능 |
| **2** | | `run_pipeline.sh` → padcirc 전용 스크립트 연결 | 🟡 버그 | `02_runp_model.csh`(padcswan) → `02_runp_model_padcirc.csh`로 수정 필요 |
| **2** | | MPI 클러스터 실제 수행 | 🔴 수작업 | wave01~28 노드 가용 확인 후 실행 |
| **3** | 가시화 결과 전달 | `maxele.63` 등 산출물 → AI 입력 경로 이동 | 🔴 미구현 | `scp_to_ai.sh` 존재하나 파이프라인 미연동 |
| **3** | | `make_tif_path_no.py`, `Model_Data_Read_Ch_data.py` 자동 실행 | 🔴 미구현 | post 완료 후 자동 트리거 필요 |
| **4** | 의사결정 에이전트 | 가시화 이미지·수치 → AI 위험도 판단 | 🔴 미구현 | Claude API 연동 |
| **4** | | 위험도 기준 정의 (임계값·판단 로직) | 🔴 수작업 (기획) | 예보관 기준 정의 필요 |
| **5** | 보고서 자동 작성 | Phase 4 판단 결과 → 보고서 초안 생성 | 🔴 미구현 | AI 에이전트 + 보고서 템플릿 |
| **5** | | 보고서 배포 (이메일·공유드라이브 등) | 🔴 미구현 | 전달 채널 정의 필요 |

---

## 즉시 해결 가능한 버그

| 파일 | 문제 | 수정 |
|------|------|------|
| `automation/run_pipeline.sh` 라인 85 | `02_runp_model.csh` (padcswan 원본) 호출 중 | `02_runp_model_padcirc.csh`로 변경 |

---

## 우선순위 작업 순서

```
① [즉시] run_pipeline.sh → padcirc 스크립트 연결 수정 (버그 수정, ~10분)
② [Phase 3] 04_post 완료 후 make_tif_path_no.py 자동 실행 연결
③ [Phase 4] 가시화 결과 → Claude API 위험도 판단 에이전트 구현
④ [Phase 5] 판단 결과 → 보고서 자동 작성 (템플릿 + 에이전트)
⑤ [통합] 전체 DRY_RUN 통합 테스트 및 로그 검증
```

---

## 담당 파트 (JM)

Phase 3~5 구현 — 가시화 결과 수신부터 AI 에이전트 보고서 작성까지.

| 작업 | 산출물 |
|------|--------|
| `run_pipeline.sh` padcirc 버그 수정 | `automation/run_pipeline.sh` |
| Phase 3 결과 전달 스크립트 | `automation/post_to_agent.sh` (예정) |
| Phase 4 의사결정 에이전트 | `automation/ai_decision.py` (예정) |
| Phase 5 보고서 자동 작성 | `automation/generate_report.py` (예정) |
