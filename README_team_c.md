# C팀 — 태풍 발생부터 의사결정 보고서 작성까지 전 과정 자동화

> 26년 예보사업부 AI·AX 해커톤 | 2026.6.30(화)~7.1(수) | 엘리스랩 부산센터

## 프로젝트 개요

태풍 통보문 수신 → 수치모형(GEO-ADCIRC, padcirc) 자동 수행 → 결과 가시화 → 의사결정 에이전트 기반 보고서 작성까지,
담당자가 수작업으로 개입하던 전 과정을 통합 자동화 체계로 구현한다.

```
[태풍 통보문 수신]
     ↓  crontab (5분 주기 감시)
[수치모형 자동 수행]  ← padcirc (ADCIRC 단독, SWAN 미연동)
     ↓  pre → model → post
[결과 가시화]         ← FigureGen / GMT 자동 생성
     ↓
[의사결정 에이전트]   ← AI 기반 위험도 판단
     ↓
[보고서 자동 작성]
```

상세 기획은 `제안자료_v3.pptx` 참고.

---

## 수행 환경

| 항목 | 내용 |
|------|------|
| 모델 | padcirc (ADCIRC, SWAN 미연동) |
| 실행파일 | `build/` 의 표준 ADCIRC 빌드 (Intel oneAPI MPI 2021.5.1) |
| 서버 | 83번 서버 (멀티노드 가능) |
| 코어 | **가변** — 상황에 맞게 조절 (스크립트 인자로 지정) |
| 격자 | `999_lteacd_edit.grd` — 484,505 노드 / 258,046 요소 |
| 시간간격 | DT = 1 초 |

### 힌남노 기준 예상 수행 시간 (padcirc)

코어 수는 가변. 아래는 6일(힌남노 전체, 약 518,400 스텝) 모의 기준 코어수별 추정:

| 코어 수 | 노드/코어 | 예상 벽시간(6일 모의) | 비고 |
|--------|----------|---------------------|------|
| 60코어  | ≈ 8,075 | **약 9~15시간** | 통신부하 적으나 코어 부족 |
| 120코어 | ≈ 4,038 | **약 5~8시간**  | 균형 잡힌 구성 |
| 240코어 | ≈ 2,019 | **약 3~5시간**  | 스케일링 효율 점감 시작 |

모의 기간별(120코어 기준):

| 모의 기간 | 시간스텝 수 | 예상 벽시간 |
|-----------|------------|------------|
| 3일 (RNDAY=3) | 259,200 | **약 2~4시간** |
| 5일 (RNDAY=5) | 432,000 | **약 4~7시간** |
| 6일 전체 (Sep 1~7) | 518,400 | **약 5~8시간** |

> **산출 근거**
> - padcirc는 padcswan 대비 SWAN 연동 오버헤드가 없어 시간스텝당 약 1.3~1.5배 빠름
> - ADCIRC는 코어당 약 2,000~4,000노드 구간에서 병렬효율 최적 → 120코어 부근이 균형점
> - 코어를 240 이상으로 늘리면 통신 비중 증가로 선형 단축은 점차 둔화
> - Hotstart 사용 시 조위 스핀업(1~2일) 제외 → 실질 모의기간 단축 가능
> - 실제 벽시간은 서버 CPU 사양·MPI 성능에 따라 ±30% 차이 발생 가능

---

## 작업 폴더 위치 (서버 공용)

```
/data1/syjeong/2026/Inundation/02_Hackathon/
├── 제안자료_v3.pptx
├── build/                              # ★ ADCIRC 실행파일 (표준 빌드)
│   ├── padcirc                         #   - 모델 본체
│   ├── adcprep                         #   - 도메인 분할
│   └── aswip                           #   - 바람장 전처리
├── TY_scripts(Crontab)/
│   └── check-tsw_hotstart.sh           # 통보문 수집 크론탭 스크립트 (5분 주기)
├── source_GEO_Edit_2025(0927)/
│   ├── 01_runp_pre.csh                 # 전처리 (바람장·조화분조·hotstart)
│   ├── 02_runp_model.csh               # 모델 수행 (padcswan 원본 — 참고용)
│   ├── 02_runp_model_padcirc.csh       # 모델 수행 (padcirc 전용 ← 이걸 쓸 것)
│   ├── 03_runp_onlytide.csh            # 조위 수행
│   ├── 04_runp_post.csh                # 후처리·가시화
│   ├── 05_remove.sh                    # 임시파일 정리
│   ├── Wind/                           # 바람장 생성
│   ├── hotstart/                       # Hotstart 초기장
│   ├── onlytide/                       # 조위 전용
│   ├── Model/
│   │   ├── Runp_NDMI_Model.csh         # padcswan 원본 (참고용)
│   │   ├── Runp_NDMI_Model_padcirc.csh # padcirc 전용 ← 이걸 쓸 것
│   │   ├── padcirc / adcprep / aswip   # build/ 에서 복사 완료 (실행권한 부여됨)
│   │   ├── fort.13 / fort.14           # 격자·조도 파일
│   │   └── ...
│   └── Post/                           # FigureGen 가시화
└── geosr-hackathon-kit-team-c/         # 이 저장소
```

> 실행파일(`padcirc`/`adcprep`/`aswip`)은 `build/` → `Model/` 로 복사 완료.
> 의존성: Intel oneAPI MPI 2021.5.1 (`/appl/opt/oneapi/mpi/2021.5.1`) — ldd 확인 완료.

---

## padcirc 수행 절차

### 1. 코어 수 지정 (가변)

코어 수는 고정하지 않고 수행 시 인자로 전달한다:

```bash
csh 02_runp_model_padcirc.csh 120   # 120코어로 수행
csh 02_runp_model_padcirc.csh 60    # 60코어로 수행
csh 02_runp_model_padcirc.csh       # 인자 생략 시 기본 120
```

### 2. (선택) 멀티노드 수행

여러 노드에 걸쳐 돌릴 경우 [Runp_NDMI_Model_padcirc.csh](../source_GEO_Edit_2025(0927)/Model/Runp_NDMI_Model_padcirc.csh) 의
노드명을 실제 83번 서버 호스트명으로 수정하고 `mpd.hosts` 자동생성 블록을 주석 해제한다.
단일 노드면 `mpd.hosts` 없이 그대로 수행된다.

```csh
set NODE1 = 실제노드1명
set NODE2 = 실제노드2명
set CORES_PER_NODE = 60
```

### 3. 전체 파이프라인 수행

```bash
cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025\(0927\)/

csh 01_runp_pre.csh                 # 전처리
csh 02_runp_model_padcirc.csh 120   # padcirc 수행 (코어수 인자)
csh 03_runp_onlytide.csh            # 조위 수행
csh 04_runp_post.csh                # 후처리·가시화
```

> adcprep는 표준 ADCIRC 2단계(`--partmesh` → `--prepall`)로 분할한다.
> (구버전 `01~03_adcprep_992p`의 3단계 방식과 다르며, 코어 수를 컴파일에 박지 않아 가변 가능)

---

## 크론탭 설정 방법

```bash
crontab -e
# 아래 한 줄 추가
*/5 * * * * /data1/syjeong/2026/Inundation/02_Hackathon/TY_scripts\(Crontab\)/check-tsw_hotstart.sh
```

사전 준비:

```bash
chmod 755 /data1/syjeong/2026/Inundation/02_Hackathon/TY_scripts\(Crontab\)/check-tsw_hotstart.sh
echo "1" > /tmp/CASE_CNT
touch /tmp/CASE2
```

---

## 팀원 접근

```bash
# 서버 내 직접 접근
/data1/syjeong/2026/Inundation/02_Hackathon/

# 저장소 클론
git clone git@github.com:duryeong/geosr-hackathon-kit-team-c.git
cd geosr-hackathon-kit-team-c
claude   # CLAUDE.md 자동 로드
```

---

## 제출 구조

```
submit/
├── PROCESS_LOG_team_c_SY.md    # 정수영 작업 로그
├── PROCESS_LOG_team_c_MS.md    # 팀원 작업 로그
├── BEFORE_AFTER.md
├── assets/
└── evidence/timestamps.txt
```
