# Before / After — ADCIRC 수행 디버깅의 자가치유(self-heal) 자동화

## 우리가 자동화한 반복 수작업
GEO-ADCIRC(padcirc) 해일모형을 돌릴 때, **수행이 실패하면 사람이 매번 원인을 추적하고 `fort.15`(제어파일)를 시행착오로 고쳐 재수행**하는 디버깅 루프. 이 "수행→실패→원인추적→파라미터 수정→재수행"을 **자가치유 순환구조 `self_heal_adcirc.sh`** 로 자동화했다. (대상: `sample_run`)

## Before (기존 수작업 디버깅)
1. `mpi.sh`로 모델을 돌리고 끝나길 기다린다.
2. **성공/실패 판정이 신뢰 불가**: ADCIRC가 수치 발산(`ErrorElev`)으로 자기중단해도 로그 끝에 `MPI terminated with Status = 0`을 찍어, `mpi.sh`의 단일 grep이 **실패를 "성공"으로 거짓 통과**시킨다. 게다가 `./padcirc > log.dat`로 **stdout만** 받아, rank0가 아닌 프로세스(예: PE0064)의 발산 메시지(stderr)는 **놓친다**.
3. 실패를 눈치채면 담당자가 `log.dat`를 수백 줄 뒤지며 원인을 추정한다(속성 불일치? CFL? 램프?). ADCIRC 에러는 segfault 주소(`0x…ef`)처럼 **불친절**해 원인 파악에 시간이 든다.
4. `fort.15` 파라미터(DT·DRAMP·TAU0·속성명…)를 **경험과 직관으로 시행착오** 수정한다. 수정 근거·이력은 대개 기록되지 않는다(구두/메모).
5. 120코어 재수행 → 또 실패 → 3~4회 반복. 공유 폴더의 파일을 직접 편집해 **다른 입력을 망가뜨릴 위험**도 있다.

## After (에이전트화 — `self_heal_adcirc.sh`)
1. **4중 성공게이트로 "진짜 완주"만 통과** — ①MPI Status=0 ②stdout·stderr **양쪽** 무발산(ErrorElev/NaN) ③RNDAY 완주(last_ts×|DT|≥RNDAY) ④`maxele.63` 생성·유한. `mpi.sh`의 거짓성공을 원천 차단하고, stderr까지 잡아 비-rank0 발산도 포착.
2. **실패 자동 분류 + 컨텍스트 발췌** — `NODAL_ATTR_NOT_FOUND / ELEV_BLOWUP / NAN / ADCPREP_FAIL / RUN_TIMEOUT / …` 로 라벨링하고 핵심 로그를 추려 패키징(환경오류는 모델 수정 대상에서 제외).
3. **Claude(소넷) headless가 원인 판단 + `fort.15`만 자동 수정** — 팀 진단 우선순위 `CHECK_PRIORITY.md`(P2 DT>0·P6 CFL≤4·P3 속성정합)와 ADCIRC v53 매뉴얼을 근거로 최소 수정 제안. **샌드박스(쓰기 fort.15 한정)+SHA 해시가드+허용줄 범위검사**로 다른 파일·물리옵션·메시는 불변 보장.
4. **회당 사람 승인** — 한 사이클 돌고 제안 diff·근거를 보여주고 정지. 사람이 승인(approve)/되돌림(revert)을 결정.
5. **누적 수정저널 `FIX_JOURNAL.md`** — 사이클마다 **①왜 오류 ②무엇을 고침 ③왜 고침(소넷 근거, 인용한 P#·v53)** 을 사람이 읽기 쉽게 자동 누적 → 디버깅 과정이 완전히 추적·재현 가능.

## 효과

| 지표 | Before | After | 효과 |
|------|--------|-------|------|
| 발산 실패 **인지** | `mpi.sh`가 Status=0으로 **거짓성공** → 못 알아챔 | 4중 게이트가 stderr `ErrorElev`까지 포착 → **정확 실패판정** | 잘못된 결과를 "성공"으로 넘기는 사고 차단 |
| stderr 포착 | 미포착(stdout만) | stdout+stderr 동시 포착·검사 | 비-rank0(PE0064 등) 발산 가시화 |
| 원인 **진단** | 사람이 log.dat 수동 분석, 경험 의존 | 자동 분류 + 소넷이 **근거(P#/v53) 제시** | 원인파악 시간↓, 근거 명시 |
| `fort.15` **수정** | 전문가 시행착오 | 소넷 자동수정(fort.15만) + 회당 승인 | 일관·최소 수정, 사람은 검토만 |
| 안전성 | 공유파일 직접편집 위험 | 샌드박스+해시복원+범위검사 | 타 입력·물리옵션·메시 불변 보장 |
| 이력 **추적** | 거의 없음(구두) | `FIX_JOURNAL` 자동 누적(왜·무엇·왜) | 재현·인수인계·채점근거 확보 |

### 실제 수행으로 확인된 결과(샘플 케이스)
- **Cycle 1** — 자동 분류 `NODAL_ATTR_NOT_FOUND`(초기화 단계 segfault, last_ts=0). 소넷이 `fort.15`의 `chezy_friction_coefficient_at_sea_floor` → `mannings_n_at_sea_floor` 로 정정(**CHECK_PRIORITY P3** 인용, `fort.13` 실제 속성과 교차검증). 사람은 segfault 주소만 보고 헤맬 지점을 자동 진단.
- **거짓성공 차단 입증** — 후속 사이클에서 `mpi_rc=0` + 로그에 `MPI terminated with Status = 0` 이 찍혔지만, **stderr의 `Elevation.gt.ErrorElev`(비-rank0 발산)** 를 게이트가 잡아 **정확히 실패로 판정**. (기존 `mpi.sh`라면 그대로 통과시켰을 상황.)
- 모든 사이클의 증상·수정·근거가 `FIX_JOURNAL.md`에 한국어로 누적되어, 디버깅 서사가 그대로 남는다.

> AI 활용 기법: Claude Code **headless 소넷 루프**(진단·수정), **팀 문서(CHECK_PRIORITY.md) 근거 주입**, 멀티에이전트(ultracode) 설계/검증, 샌드박스 자동수정. 산출물: `automation/self_heal_adcirc.sh`, 세션별 `automation/logs/selfheal/<세션>/FIX_JOURNAL.md`.
