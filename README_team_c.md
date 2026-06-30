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

## 가상태풍 테스트베드

전체 파이프라인(통보문 → 모델 → 가시화 → 보고서)을 실제 태풍 시즌이 아니어도 구동·검증할 수 있도록,
**한반도 남동해안(부산·경남)을 직격하는 가상태풍**을 통보문과 동일한 형식으로 만들어 두었다.

- 입력 파일: [source_GEO_Edit_2025(0927)/typhoon.in](../source_GEO_Edit_2025(0927)/typhoon.in)
- 형식: 실제 통보문 백업(`NOTICE_BACKUP/*.txt`)과 **동일** → 전처리기(`mk_pre_fort15_22_26_MUN_v2.2`)가 그대로 읽음
- 트랙 길이: 약 2.5일(60시간, 6시간 간격 11개 시점)

### 입력 형식

```
태풍명  번호  연도
시각(YYYYMMDDHH, UTC)  더미  더미  위도(×10)  경도(×10)  중심기압(hPa)
```

> 풍속·최대풍반경은 전처리기가 중심기압에서 자동 산정(Vickery/Willoughby/Powell 공식).
> 사용자는 **위치와 중심기압만** 입력하면 된다. 위/경도는 0.1도 단위(예: `350` = 35.0°N).

### 가상태풍 트랙 (NARITEST, 2025)

| 시각(UTC) | 위치 | 중심기압 | 단계 |
|-----------|------|---------|------|
| 09-01 00Z | 28.0°N 125.0°E | 962 hPa | 제주 남서 먼바다 |
| 09-01 12Z | 30.5°N 126.2°E | 952 hPa | 북동진하며 발달 |
| 09-02 00Z | 33.0°N 127.4°E | **945 hPa** | 최성기, 제주 동쪽 통과 |
| 09-02 12Z | 35.0°N 128.6°E | 955 hPa | 남해안 접근 |
| 09-02 18Z | 35.7°N 129.2°E | 968 hPa | **경남 상륙** |
| 09-03 00Z | 36.6°N 129.8°E | 978 hPa | 내륙·동해 진입, 약화 |
| 09-03 12Z | 38.6°N 131.2°E | 992 hPa | 동해상 소멸기 |

### 구동 방법

```bash
cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025\(0927\)/

# typhoon.in 은 이미 가상태풍으로 작성돼 있음.
# 전처리기가 참조하는 통보문 백업 경로에 '빈 파일'만 두면
# → "백업 없음" 분기로 typhoon.in 만 사용해 fort.22/fort.15 생성
mkdir -p /home/storm/GEOSR/2022_v53_geosr/NOTICE_BACKUP
touch    /home/storm/GEOSR/2022_v53_geosr/NOTICE_BACKUP/2025_90_NARITEST.txt

# 전체 파이프라인 수행
csh 01_runp_pre.csh                 # typhoon.in → 바람장·fort.22·fort.15
csh 02_runp_model_padcirc.csh 240   # padcirc 모델 수행 (코어수 인자)
csh 03_runp_onlytide.csh            # 조위 분리
csh 04_runp_post.csh                # 가시화
```

> **NOTICE_BACKUP 경로 주의**: 전처리기 바이너리에 운영서버 경로
> `/home/storm/GEOSR/2022_v53_geosr/NOTICE_BACKUP/{연도}_{번호}_{태풍명}.txt` 가 하드코딩돼 있다.
> 이 경로에 **빈 파일**을 두면 typhoon.in 만으로 동작한다(파일 내용이 있으면 백업+typhoon.in 병합).
> 해당 디렉토리 생성·쓰기 권한이 없는 서버에서는 운영자에게 경로 준비를 요청한다.

---

## 수행 환경

| 항목 | 내용 |
|------|------|
| 모델 | padcirc (ADCIRC, SWAN 미연동) |
| 실행파일 | `build/` 의 표준 ADCIRC 빌드 (Intel oneAPI MPI 2021.5.1) |
| 서버 | 83번 서버 (멀티노드 가능) |
| 코어 | **가변** — 상황에 맞게 조절 (스크립트 인자로 지정) |
| 격자 | `Model/fort.14` (`G_100m_utm_msl`) — **1,091,756 노드 / 580,541 요소** (약 100 m 고해상도) |
| 좌표계 | 경위도 (ICS=2, CPP 투영) — 이름은 utm이나 노드 좌표는 경위도 |
| 시간간격 | DT = 1 초 |

> 격자는 `Model/fort.14`를 사용한다. (`fort_org.14`(48만 노드)는 구버전 저해상도 격자 — 미사용)

### 가상태풍 테스트베드 기준 예상 수행 시간 (padcirc)

테스트베드 트랙(`typhoon.in`)은 약 **2.5일(60시간)** 길이이고, 전처리에 **콜드스타트 3일**이 내장되어
실제 모의 기간은 **약 5.5일(≈ 475,200 스텝 @ DT=1s)** 이다. 코어수별 추정:

| 코어 수 | 노드/코어 | 예상 벽시간(트랙 2.5일 + 콜드 3일) | 비고 |
|--------|----------|------------------------------|------|
| 120코어 | ≈ 9,098 | **약 12~20시간** | 코어당 부하 큼(109만 노드) |
| 240코어 | ≈ 4,549 | **약 7~12시간**  | 균형점 부근 |
| 480코어 | ≈ 2,275 | **약 4~7시간**   | 고해상도 격자 권장 구성 |

> **산출 근거**
> - 격자가 109만 노드(구 48만의 2.25배)로 커서 계산량이 비례 증가
> - padcirc는 SWAN 미연동이라 시간스텝당 약 1.3~1.5배 빠름
> - ADCIRC는 코어당 약 2,000~5,000노드 구간에서 병렬효율 최적 → 109만 노드엔 240~480코어 적합
> - 콜드스타트 3일은 전처리(`mk_pre…`) 소스에 하드코딩(`coldstart_day=3.0`) — 줄이려면 재컴파일 필요
> - 100 m 격자는 CFL 조건상 DT를 더 줄여야 할 수 있어(0.5s 등) 그 경우 벽시간 비례 증가
> - 실제 벽시간은 서버 CPU·MPI 성능에 따라 ±30~50% 편차 가능 — 첫 수행 시 `runtime.out`으로 실측 권장

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
│   │   ├── fort.14                      # ★ 사용 격자 (G_100m_utm_msl, 109만 노드)
│   │   ├── fort.13                      # 조도(Manning's n) 파일
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
