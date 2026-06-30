# automation/ — GEO-ADCIRC 태풍 침수모형 파이프라인 (복구·현대화)

C팀 자동화 대상의 **①태풍 통보문 감시 → ②모델 수행** 구간을 돌아가는 상태로 정리한 모듈.
레거시 `check-tsw_hotstart.sh`(2022)의 깨진 부분을 고치고, 클러스터 없이도 흐름을 검증할 수 있게 했다.

## 파일
| 파일 | 역할 |
|---|---|
| `check_typhoon.sh` | 통보문 신규 케이스 감시 → 파이프라인 자동 기동 (crontab 5분 주기) |
| `run_pipeline.sh`  | 자동 오케스트레이터 — 소스 복사 후 01→02→03→04 일괄 수행 (감시에서 호출) |
| `run_manual.sh`    | **수동 순차 수행기** — 소스 폴더에서 사람이 단계별로 직접 실행(단계 확인·단일단계·코어수 인자) |
| `logs/`            | 실행 로그 (git 미추적) |

### 수동 순차 수행 (run_manual.sh)
담당자가 소스 폴더에서 직접 01→02→03→04를 순서대로 돌릴 때 사용. 단계 누락·순서 실수를 막고, 각 단계 전 확인(Enter)·단일 단계 수행·코어 수 지정을 지원.
```bash
cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)/
/path/to/automation/run_manual.sh 120        # 120코어로 1→4 순차(각 단계 확인)
/path/to/automation/run_manual.sh -y 120     # 확인 없이 연속 수행
/path/to/automation/run_manual.sh -s 2 -n 60 # 02_model만 60코어로 수행
```
> 소스 폴더가 아니면 안전 가드가 작동해 아무것도 실행하지 않는다.

## 모델: padcirc (2026-06-30 전환 반영)
대상 모델이 **padcswan(ADCIRC+SWAN, 992코어 고정) → padcirc(ADCIRC 단독, SWAN 미연동, 코어 가변)** 으로 변경됨.
- 모델 본수행 스크립트: `02_runp_model_padcirc.csh <코어수>` (기본 120)
- adcprep 표준 2단계(`--partmesh` → `--prepall`), 코어 수를 인자로 전달(가변)
- 오케스트레이터는 `NP` 환경변수로 코어 수를 전달 (`NP=120` 기본)

## 레거시 대비 고친 점
1. **경로 하드코딩 제거** — `/home/storm/2022/...` → 환경변수(`BASE/DATA_DIR/RUN_DIR/SRC_DIR`)로 분리. 2026 경로에서 바로 동작.
2. **단계 호출 정정** — 레거시는 `01→02→03(=post)`로 호출했으나 실제 폴더 구조는 `01_pre / 02_model / 03_onlytide / 04_post`. 누락됐던 **onlytide**를 살리고 post를 04로 정정.
3. **모델 padcirc 전환 반영** — 02단계를 `02_runp_model_padcirc.csh`로 호출하고 코어 수(`NP`)를 인자로 전달.
4. **상태관리 견고화** — `/tmp/CASE_CNT,CASE1,CASE2`(재부팅·tmp정리에 취약) → 영속 상태파일에 **처리완료 케이스 목록**을 누적. 중복수행 방지 + 실패 시 다음 주기 재시도.
5. **클러스터 미가용 안전장치** — `mpirun` 없으면 실제 수행을 막고, `DRY_RUN=1`로 전체 흐름을 검증 가능.

## 실행

### 테스트 (클러스터 불필요)
```bash
SRC="/data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)" \
RUN="/tmp/geosr_run" NP=120 DRY_RUN=1 \
./run_pipeline.sh 2026063012_TY01
```

### 실제 운영 (83번 서버, 멀티노드 가능)
```bash
# crontab -e
*/5 * * * * BASE=/data1/syjeong/2026/Inundation/02_Hackathon \
  DATA_DIR=/path/to/통보문수신폴더 NP=120 \
  /data1/.../automation/check_typhoon.sh >> /data1/.../automation/logs/monitor.log 2>&1
```

## 남은 단계 (③④⑤ — 다음 모듈)
모델 산출물(`maxele.63`, FigureGen 결과) → **가시화 정리 → 의사결정 에이전트(위험도 판단) → 보고서 자동작성**.
`Post/`의 `make_tif_path_no.py`, `Model_Data_Read_Ch_data.py`, `scp_to_ai.sh`가 AI 핸드오프 연결고리(2025 추가분)로 보이며, 이를 에이전트 보고서 생성과 연결할 예정.

> ⚠️ 실제 ADCIRC+SWAN 본수행은 992코어 MPI 클러스터에서만 가능. 이 저장소에서는 오케스트레이션 흐름을 DRY_RUN으로 검증함.
