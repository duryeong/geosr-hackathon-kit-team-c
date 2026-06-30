# automation/ — GEO-ADCIRC 태풍 침수모형 파이프라인 (복구·현대화)

C팀 자동화 대상의 **①태풍 통보문 감시 → ②모델 수행** 구간을 돌아가는 상태로 정리한 모듈.
레거시 `check-tsw_hotstart.sh`(2022)의 깨진 부분을 고치고, 클러스터 없이도 흐름을 검증할 수 있게 했다.

## 파일
| 파일 | 역할 |
|---|---|
| `check_typhoon.sh` | 통보문 신규 케이스 감시 → 파이프라인 자동 기동 (crontab 5분 주기) |
| `run_pipeline.sh`  | 단일 케이스 오케스트레이터 (01_pre → 02_model → 03_onlytide → 04_post) |
| `logs/`            | 실행 로그 (git 미추적) |

## 레거시 대비 고친 점
1. **경로 하드코딩 제거** — `/home/storm/2022/...` → 환경변수(`BASE/DATA_DIR/RUN_DIR/SRC_DIR`)로 분리. 2026 경로에서 바로 동작.
2. **단계 호출 정정** — 레거시는 `01→02→03(=post)`로 호출했으나 실제 폴더 구조는 `01_pre / 02_model / 03_onlytide / 04_post`. 누락됐던 **onlytide**를 살리고 post를 04로 정정.
3. **상태관리 견고화** — `/tmp/CASE_CNT,CASE1,CASE2`(재부팅·tmp정리에 취약) → 영속 상태파일에 **처리완료 케이스 목록**을 누적. 중복수행 방지 + 실패 시 다음 주기 재시도.
4. **클러스터 미가용 안전장치** — `mpirun` 없으면 실제 수행을 막고, `DRY_RUN=1`로 전체 흐름을 검증 가능.

## 실행

### 테스트 (클러스터 불필요)
```bash
SRC="/data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)" \
RUN="/tmp/geosr_run" DRY_RUN=1 \
./run_pipeline.sh 2026063012_TY01
```

### 실제 운영 (wave01~28 클러스터)
```bash
# crontab -e
*/5 * * * * BASE=/data1/syjeong/2026/Inundation/02_Hackathon \
  DATA_DIR=/path/to/통보문수신폴더 \
  /data1/.../automation/check_typhoon.sh >> /data1/.../automation/logs/monitor.log 2>&1
```

## 남은 단계 (③④⑤ — 다음 모듈)
모델 산출물(`maxele.63`, FigureGen 결과) → **가시화 정리 → 의사결정 에이전트(위험도 판단) → 보고서 자동작성**.
`Post/`의 `make_tif_path_no.py`, `Model_Data_Read_Ch_data.py`, `scp_to_ai.sh`가 AI 핸드오프 연결고리(2025 추가분)로 보이며, 이를 에이전트 보고서 생성과 연결할 예정.

> ⚠️ 실제 ADCIRC+SWAN 본수행은 992코어 MPI 클러스터에서만 가능. 이 저장소에서는 오케스트레이션 흐름을 DRY_RUN으로 검증함.
