# ADCIRC 진단 스크립트 개발 계획서

`CHECK_PRIORITY.md` 기반. 최종 산출물은 `automation/check_run.py`.

---

## 설계 원칙

| 원칙 | 내용 |
|------|------|
| **병렬 진단** | P1-a ~ P6 전 항목을 동시에 실행, 결과 수집 후 일괄 판정 |
| **우선순위 = 수정 순서** | FAIL 여러 개일 때 P1-a부터 순서대로 수정 |
| **즉시 사용 가능** | `python check_run.py [RUN_DIR]` 한 줄로 실행 |
| **출력 레벨** | `PASS ✔` / `WARN △` / `FAIL ✘` / `INFO ℹ` / `SKIP —` |

---

## 전체 Phase 구성

| Phase | 구현 내용 | 핵심 함수 | 난이도 | 선행 조건 |
|-------|-----------|----------|--------|-----------|
| 0 | 기반 구조 · 출력 포맷 · 병렬 실행 프레임 | `main()`, `run_parallel()` | ★☆☆ | 없음 |
| 1 | P1-a — 필수파일 존재 | `check_p1a()` | ★☆☆ | Phase 0 |
| 2 | P1-b — NP 일관성 | `check_p1b()` | ★☆☆ | Phase 0 |
| 3 | P2 — fort.15 파서 · 파라미터 검증 | `parse_fort15()`, `check_p2()` | ★★☆ | Phase 0 |
| 4 | P3 — 조건부 필수파일 | `check_p3()` | ★★☆ | Phase 3 |
| 5 | P4 — 바람장–모의기간 일치 | `check_p4()` | ★★☆ | Phase 3 |
| 6 | P5 — Hotstart 타임스탬프 | `check_p5()` | ★★★ | Phase 3 |
| 7 | P6 — CFL 안정성 | `check_p6()` | ★★★ | Phase 3 |

> **Phase 3(`parse_fort15`)이 핵심 의존성** — P3~P6이 모두 이 파서의 반환값을 사용한다.  
> Phase 0~2는 fort.15 파싱 없이 독립 실행 가능 → Phase 3과 병렬 개발 가능.

---

## Phase 0 — 기반 구조 · 병렬 실행 프레임

| 항목 | 내용 |
|------|------|
| **목표** | 병렬 진단 프레임 및 공통 출력 포맷 구축 |
| **산출물** | `automation/check_run.py` (skeleton) |
| **구현 내용** | ① `check_run.py [RUN_DIR]` 실행 인터페이스 (기본값: 현재 디렉터리) |
| | ② `ThreadPoolExecutor`로 P1-a ~ P6 동시 실행 |
| | ③ 결과 수집 후 FAIL/WARN/PASS 일괄 판정 |
| | ④ 판정 기준: FAIL 있음 → 중단 / WARN만 → 경고 후 진행 / 모두 PASS → 진행 |
| | ⑤ 출력 포맷: `[P1-a] ✔ adcprep 존재·실행권한 확인` |
| | ⑥ 최종 요약: PASS N / WARN N / FAIL N / SKIP N 개수 출력 |
| **완료 기준** | 빈 체크 함수 6개를 병렬 실행 시 정상 출력 |

---

## Phase 1 — P1-a 필수파일 존재

| 항목 | 내용 |
|------|------|
| **목표** | 5개 필수파일 존재·권한 자동 확인 |
| **산출물** | `check_p1a()` |
| **구현 내용** | ① `adcprep`, `padcirc` — `os.path.exists` + `os.access(X_OK)` |
| | ② `fort.14`, `fort.15` — 존재 + `os.path.getsize() > 0` |
| | ③ `machine` — 존재 여부 |
| **완료 기준** | sample_run 폴더에서 5개 항목 모두 PASS |

---

## Phase 2 — P1-b NP 일관성

| 항목 | 내용 |
|------|------|
| **목표** | mpi.sh · machine 파일에서 NP 추출 후 3자 일치 확인 |
| **산출물** | `check_p1b()` |
| **구현 내용** | ① `mpi.sh`에서 `adcprep --np NP` 파싱 |
| | ② `mpi.sh`에서 `mpirun -n NP` 파싱 |
| | ③ `machine` 파일 슬롯 수 산출 (`hostname:N` 또는 줄당 1슬롯) |
| | ④ 불일치 시 세 값 모두 출력 |
| **완료 기준** | `--np 120`, `-n 120`, machine 120줄 → 3자 일치 PASS |

---

## Phase 3 — P2 fort.15 파서 · 파라미터 검증

> **핵심 Phase** — P3~P6 전체가 이 파서 반환값에 의존한다.

| 항목 | 내용 |
|------|------|
| **목표** | fort.15 파싱 및 가변 파라미터 범위 검증 |
| **산출물** | `parse_fort15()`, `check_p2()` |
| **파서 구현** | ① `!` 이후 코멘트 제거 후 토큰 순차 파싱 |
| | ② NWP 값만큼 속성명 줄 건너뜀 (오프셋 가변 처리 필수) |
| | ③ 반환: `dict { IHOT, NWS, NWP, NWP_ATTRS, NOLIBF, DT, STATIM, RNDAY, DRAMP }` |
| **검증 구현** | ④ `RNDAY > 0` 및 `RNDAY > DRAMP` |
| | ⑤ `DT > 0` |
| | ⑥ `IHOT in (0, 1, 2)` |
| | ⑦ IHOT=0 시 `STATIM == 0.0` 권고 (WARN) |
| **파싱 주의** | NWP 속성명 줄 수가 가변 → 인덱스 고정 불가, 순차 파싱 필수 |
| **완료 기준** | sample_run/fort.15: IHOT=0, NWS=0, DT=100, RNDAY=3.0 정상 추출 |

---

## Phase 4 — P3 조건부 필수파일

| 항목 | 내용 |
|------|------|
| **목표** | NWS·NWP·IHOT 값에 따른 조건부 파일 존재·속성 확인 |
| **산출물** | `check_p3()` |
| **구현 내용** | ① NWS 분기: 0→SKIP, ±8→fort.221+222, ±19/±20→fort.22 |
| | ② NWP > 0 → fort.13 존재 확인 |
| | ③ NWP > 0 → fort.13 속성 수 == NWP 일치 확인 |
| | ④ NOLIBF=2 → fort.13에 `mannings_n_at_sea_floor` 존재 확인 |
| | ⑤ IHOT=1 → fort.67, IHOT=2 → fort.68 존재 확인 |
| **완료 기준** | NWS=0, NWP=2, IHOT=0 환경에서 fort.13 속성 2개 확인 PASS |

---

## Phase 5 — P4 바람장–모의기간 일치

| 항목 | 내용 |
|------|------|
| **목표** | fort.22 트랙 시각 범위가 fort.15 모의기간을 완전 커버하는지 확인 |
| **산출물** | `check_p4()` |
| **구현 내용** | ① NWS=0 → SKIP |
| | ② fort.22 전 줄에서 `YYYYMMDDHH` 파싱 |
| | ③ 첫 트랙 시각 ≤ STATIM 기준 날짜 |
| | ④ 마지막 트랙 시각 ≥ STATIM + RNDAY 기준 날짜 |
| | ⑤ 중복·역순 시각 존재 여부 확인 |
| **시각 변환** | fort.15 RNDAY(days) + REFTIM → `YYYYMMDDHH` 변환 함수 필요 |
| **완료 기준** | NARITEST fort.22 로드 후 트랙 범위 출력 및 RNDAY 커버 확인 |

---

## Phase 6 — P5 Hotstart 타임스탬프

| 항목 | 내용 |
|------|------|
| **목표** | IHOT>0 시 fort.67/68 마지막 타임스탬프 == fort.15 STATIM 확인 |
| **산출물** | `check_p5()` |
| **구현 내용** | ① IHOT=0 → SKIP |
| | ② fort.67/68 바이너리에서 타임스탬프 레코드 읽기 |
| | ③ 읽은 타임스탬프(days) vs fort.15 STATIM 비교 |
| | ④ 불일치 시 두 값 함께 출력 |
| **포맷 참고** | ADCIRC hotstart 바이너리: Fortran 비정형 레코드 (`struct.unpack`) |
| **완료 기준** | IHOT=0 → SKIP 정상, IHOT>0 → 타임스탬프 추출 및 비교 성공 |

---

## Phase 7 — P6 CFL 안정성

| 항목 | 내용 |
|------|------|
| **목표** | DT와 격자 해상도 조합으로 CFL 추정값 계산 및 판정 |
| **산출물** | `check_p6()` |
| **구현 내용** | ① fort.14 첫 두 줄에서 NE, NP 읽기 |
| | ② `C > 0` 확인: DT · h_max · dx_min 모두 양수 필수 → 위반 시 FAIL |
| | ③ NP 수로 격자 해상도 클래스 추정 (NP ≥ 300,000 → 100m급 등) |
| | ④ `C = sqrt(g × h_max) × DT / dx_min` 격자 클래스별 참고값 표 출력 |
| | ⑤ C ≤ 4 → PASS / 4 < C ≤ 8 → WARN / C > 8 → FAIL |
| **완료 기준** | DT=2s, NP=377,000 → C 추정값 출력 및 PASS |

---

## 병렬 실행 구조 (Phase 0 상세)

```python
# 병렬 진단 흐름 (ThreadPoolExecutor)
with ThreadPoolExecutor() as ex:
    futures = {
        ex.submit(check_p1a, run_dir): "P1-a",
        ex.submit(check_p1b, run_dir): "P1-b",
        ex.submit(check_p2,  fort15 ): "P2",
        ex.submit(check_p3,  fort15 ): "P3",   # parse_fort15 결과 공유
        ex.submit(check_p4,  fort15 ): "P4",
        ex.submit(check_p5,  fort15 ): "P5",
        ex.submit(check_p6,  fort15 ): "P6",
    }

# 결과 수집 후 일괄 판정
results = {label: f.result() for f, label in futures.items()}

if any(r.level == "FAIL" for r in results.values()):
    print("수행 중단 — FAIL 항목 수정 후 재진단")
elif any(r.level == "WARN" for r in results.values()):
    print("경고 있음 — 확인 후 수행 진행")
else:
    print("전 항목 PASS — mpi.sh 수행")
```

> **주의**: P3~P6은 `parse_fort15()` 결과를 공유한다.  
> fort.15 파싱은 1회만 수행 후 결과를 각 체크 함수에 인자로 전달한다.

---

## 전체 개발 일정 요약

| Phase | 구현 항목 | 핵심 함수 | 상태 |
|-------|-----------|----------|------|
| 0 | 기반 구조 · 병렬 프레임 | `main()`, `run_parallel()` | 미구현 |
| 1 | P1-a 필수파일 존재 | `check_p1a()` | 미구현 |
| 2 | P1-b NP 일관성 | `check_p1b()` | 미구현 |
| 3 | P2 fort.15 파서·파라미터 | `parse_fort15()`, `check_p2()` | 미구현 |
| 4 | P3 조건부 필수파일 | `check_p3()` | 미구현 |
| 5 | P4 바람장–모의기간 | `check_p4()` | 미구현 |
| 6 | P5 Hotstart 타임스탬프 | `check_p5()` | 미구현 |
| 7 | P6 CFL 안정성 | `check_p6()` | 미구현 |
