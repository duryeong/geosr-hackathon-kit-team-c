# ADCIRC 진단 스크립트 개발 계획서

`CHECK_PRIORITY.md` 기반으로 `check_run.py` (또는 `check_run.sh`)를 단계적으로 구현한다.  
각 Phase는 독립 실행 가능하며, 완료된 Phase부터 실제 수행에 바로 투입한다.

---

## 전체 Phase 구성

| Phase | 구현 대상 우선순위 | 핵심 기술 | 예상 난이도 | 선행 조건 |
|-------|------------------|-----------|------------|-----------|
| 0 | 기반 구조 | 스크립트 skeleton, 출력 포맷, 실행 인터페이스 | ★☆☆ | 없음 |
| 1 | P1-a — 필수파일 존재 | 파일 시스템 접근, 권한 확인 | ★☆☆ | Phase 0 |
| 2 | P1-b — NP 일관성 | 텍스트 파싱 (mpi.sh, machine) | ★☆☆ | Phase 0 |
| 3 | P2 — fort.15 파라미터 | fort.15 파서 (코멘트 제거, NWP 오프셋 처리) | ★★☆ | Phase 0 |
| 4 | P3 — 조건부 필수파일 | NWS·NWP·IHOT 분기, 속성명 비교 | ★★☆ | Phase 3 |
| 5 | P4 — 바람장–모의기간 일치 | fort.22 시각 파싱, 범위 비교 | ★★☆ | Phase 3 |
| 6 | P5 — Hotstart 타임스탬프 | fort.67/68 바이너리 타임스탬프 읽기 | ★★★ | Phase 3 |
| 7 | P6 — CFL 안정성 | fort.14 헤더 읽기, DT×파속/격자간격 추정 | ★★★ | Phase 3 |

---

## Phase 0 — 기반 구조

| 항목 | 내용 |
|------|------|
| **목표** | 스크립트 뼈대 구성 및 공통 출력 포맷 정의 |
| **산출물** | `automation/check_run.py` (skeleton) |
| **구현 내용** | ① `check_run.py [RUN_DIR]` 실행 인터페이스 (기본값: 현재 디렉터리) |
| | ② 결과 레벨 정의: `PASS ✔` / `WARN △` / `FAIL ✘` / `INFO ℹ` |
| | ③ Priority 섹션별 헤더 출력 구조 |
| | ④ 최종 요약 (통과/경고/실패 개수) 출력 |
| **출력 예시** | `[P1-a] ✔ adcprep 존재·실행권한 확인` |
| **완료 기준** | `python check_run.py` 실행 시 빈 체크 목록이라도 정상 출력 |

---

## Phase 1 — P1-a 필수파일 존재

| 항목 | 내용 |
|------|------|
| **목표** | 5개 필수파일 존재·권한 자동 확인 |
| **산출물** | `check_run.py` 내 `check_p1a()` 함수 |
| **구현 내용** | ① `adcprep`, `padcirc` — `os.path.exists` + `os.access(X_OK)` |
| | ② `fort.14`, `fort.15` — 존재 + `os.path.getsize() > 0` |
| | ③ `machine` — 존재 여부 |
| **판정 기준** | 하나라도 FAIL → 이후 Phase 건너뜀, 즉시 종료 메시지 출력 |
| **완료 기준** | sample_run 폴더에서 실행 시 5개 항목 모두 PASS |

---

## Phase 2 — P1-b NP 일관성

| 항목 | 내용 |
|------|------|
| **목표** | mpi.sh · machine 파일에서 NP 추출 후 3자 일치 확인 |
| **산출물** | `check_run.py` 내 `check_p1b()` 함수 |
| **구현 내용** | ① `mpi.sh` 에서 `--np NP` 파싱 (adcprep 인자) |
| | ② `mpi.sh` 에서 `-n NP` 파싱 (mpirun 인자) |
| | ③ `machine` 파일 슬롯 수 계산 (줄 수 또는 `:` 구분 슬롯 합산) |
| | ④ ①②③ 불일치 시 어디가 다른지 구체 값 표시 |
| **엣지 케이스** | machine 파일 형식: `hostname:slots` vs `hostname` (줄당 1슬롯) 구분 |
| **완료 기준** | `mpi.sh -n 120`, `--np 120`, machine 120줄 → 3자 일치 PASS |

---

## Phase 3 — P2 fort.15 파라미터 파싱

> **핵심 Phase** — P3~P6이 모두 이 파서에 의존한다.

| 항목 | 내용 |
|------|------|
| **목표** | fort.15에서 핵심 파라미터 추출 및 범위 검증 |
| **산출물** | `check_run.py` 내 `parse_fort15()` + `check_p2()` 함수 |
| **구현 내용 — 파서** | ① 코멘트(`!` 이후) 제거 후 토큰 순차 파싱 |
| | ② NWP 값만큼 속성명 줄 건너뜀 (오프셋 가변 처리 필수) |
| | ③ 반환: `dict { IHOT, NWS, NWP, NWP_ATTRS, DT, STATIM, RNDAY, DRAMP, NOLIBF }` |
| **구현 내용 — 검증** | ④ `RNDAY > 0` 확인 |
| | ⑤ `RNDAY > DRAMP` 확인 |
| | ⑥ `DT > 0` 확인 |
| | ⑦ `IHOT in (0, 1, 2)` 확인 |
| | ⑧ IHOT=0 시 `STATIM == 0.0` 권고 (WARN) |
| **파싱 주의** | NWP 속성명이 가변 개수로 줄을 차지 → 인덱스 고정 불가, 순차 파싱 필수 |
| **완료 기준** | sample_run/fort.15 파싱 후 IHOT=0, NWS=0, DT=100, RNDAY=3.0 정상 추출 |

---

## Phase 4 — P3 조건부 필수파일

| 항목 | 내용 |
|------|------|
| **목표** | NWS·NWP·IHOT 값에 따른 조건부 파일 존재·속성 확인 |
| **산출물** | `check_run.py` 내 `check_p3()` 함수 |
| **구현 내용** | ① NWS 분기: 0→skip, ±8→fort.221+222, ±19/±20→fort.22 |
| | ② NWP>0 → fort.13 존재 확인 |
| | ③ NWP>0 → fort.13 첫 줄 속성 수 == NWP 일치 확인 |
| | ④ NOLIBF=2 → fort.13 내 `mannings_n_at_sea_floor` 속성명 존재 확인 |
| | ⑤ IHOT=1 → fort.67, IHOT=2 → fort.68 존재 확인 |
| **완료 기준** | NWS=0, NWP=2, IHOT=0 환경에서 fort.13 존재·속성 2개 확인 PASS |

---

## Phase 5 — P4 바람장–모의기간 일치

| 항목 | 내용 |
|------|------|
| **목표** | fort.22 트랙 시각 범위가 fort.15 모의기간을 완전 커버하는지 확인 |
| **산출물** | `check_run.py` 내 `check_p4()` 함수 |
| **구현 내용** | ① fort.22 전 줄 읽어 `YYYYMMDDHH` 파싱 |
| | ② 첫 트랙 시각 ≤ STATIM 기준 날짜 확인 |
| | ③ 마지막 트랙 시각 ≥ STATIM+RNDAY 기준 날짜 확인 |
| | ④ 트랙 시각 중복·역순 여부 확인 |
| | ⑤ 트랙 간격 균일성 확인 (6시간 기준, 편차 허용 범위 설정) |
| **시각 변환** | fort.15 RNDAY(days) → `REFTIM + RNDAY` → `YYYYMMDDHH` 변환 함수 필요 |
| **NWS=0 시** | 이 체크 건너뜀 (skip) |
| **완료 기준** | NARITEST fort.22 로드 후 트랙 첫·끝 시각 출력 및 RNDAY 커버 확인 |

---

## Phase 6 — P5 Hotstart 타임스탬프

| 항목 | 내용 |
|------|------|
| **목표** | IHOT>0 시 fort.67/68 마지막 타임스탬프 == fort.15 STATIM 확인 |
| **산출물** | `check_run.py` 내 `check_p5()` 함수 |
| **구현 내용** | ① IHOT=0 → skip |
| | ② fort.67/68 바이너리에서 타임스탬프 레코드 읽기 (ADCIRC 포맷 기준) |
| | ③ 읽은 타임스탬프(days) vs fort.15 STATIM 비교 |
| | ④ 불일치 시 두 값 함께 출력 (진단 용이) |
| **포맷 참고** | ADCIRC hotstart 바이너리: Fortran 비정형 레코드 (`struct.unpack`) |
| **완료 기준** | IHOT=0 환경에서 skip 정상 동작, IHOT>0 환경에서 타임스탬프 추출 성공 |

---

## Phase 7 — P6 CFL 안정성

| 항목 | 내용 |
|------|------|
| **목표** | DT와 격자 해상도 조합으로 CFL 추정값 제시 |
| **산출물** | `check_run.py` 내 `check_p6()` 함수 |
| **구현 내용** | ① fort.14 첫 두 줄에서 NE, NP 읽기 |
| | ② `C > 0` 확인 (DT · h_max · dx_min 모두 양수 필수) — 위반 시 즉시 FAIL |
| | ③ `C = sqrt(g × h_max) × DT / dx_min` 격자별 참고값 표 출력 |
| | ④ DT 값과 격자 해상도 클래스로 PASS/WARN/FAIL 판정 |
| **격자 해상도 추정** | fort.14 직접 파싱 대신 NP 수로 격자 해상도 클래스 추정 |
| | NP ≥ 300,000 → 100m급, NP ≥ 50,000 → 500m급, 그 외 → 1km급 |
| **완료 기준** | DT=2s, NP=377,000 (저해상도 격자) → CFL 추정값 출력 및 PASS |

---

## 전체 개발 일정 요약

| Phase | 구현 항목 | 산출물 함수 | 상태 |
|-------|-----------|------------|------|
| 0 | 기반 구조·출력 포맷 | `main()`, `print_result()` | 미구현 |
| 1 | P1-a 필수파일 존재 | `check_p1a()` | 미구현 |
| 2 | P1-b NP 일관성 | `check_p1b()` | 미구현 |
| 3 | P2 fort.15 파서·파라미터 | `parse_fort15()`, `check_p2()` | 미구현 |
| 4 | P3 조건부 필수파일 | `check_p3()` | 미구현 |
| 5 | P4 바람장–모의기간 | `check_p4()` | 미구현 |
| 6 | P5 Hotstart 타임스탬프 | `check_p5()` | 미구현 |
| 7 | P6 CFL 안정성 | `check_p6()` | 미구현 |

> Phase 3 (`parse_fort15`)이 핵심 의존성. 이것부터 완성 후 나머지 병렬 진행 가능.
