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

통보문 입력 체계를 그대로 모사하기 위해 **2단계 입력 구조**로 구성했다:

| 파일 | 역할 | 내용 |
|------|------|------|
| `NB/2025_90_NARITEST.txt` | 통보문 **백업**(과거 누적) | 트랙 1~6번 시점 |
| `source_GEO_Edit_2025(0927)/typhoon.in` | **최신 통보** | 헤더 + 트랙 7번 시점 |

전처리기(`mk_pre_fort15_22_26_MUN_v2.2`)가 둘을 병합 → 전체 11시점 트랙으로 `fort.22`/`fort.15` 생성.
실제 운영에서 통보문이 도착할 때마다 백업에 누적되고 최신본은 typhoon.in으로 들어오는 흐름과 동일하다.

### 입력 형식

```
태풍명  번호  연도                                  ← typhoon.in 첫 줄(헤더)
시각(YYYYMMDDHH, UTC)  더미  더미  위도(×10)  경도(×10)  중심기압(hPa)  ← 트랙점
```

> 풍속·최대풍반경은 전처리기가 중심기압에서 자동 산정(Vickery/Willoughby/Powell 공식).
> 사용자는 **위치와 중심기압만** 입력하면 된다. 위/경도는 0.1도 단위(예: `350` = 35.0°N).
> (백업 파일은 헤더 없이 트랙점만, typhoon.in은 헤더 포함)

### 가상태풍 트랙 (NARITEST, 2025) — 검증 완료

빠른 북상으로 1.5일에 압축한 경남 직격 시나리오 (6시간 간격 7시점):

| 시각(UTC) | 위치 | 중심기압 | 단계 |
|-----------|------|---------|------|
| 09-01 00Z | 28.5°N 125.5°E | 970 hPa | 제주 남쪽 먼바다 |
| 09-01 12Z | 31.5°N 127.0°E | 950 hPa | 북상하며 발달 |
| 09-01 18Z | 33.0°N 127.8°E | **945 hPa** | 최성기 |
| 09-02 00Z | 34.5°N 128.5°E | 955 hPa | 남해안 접근 |
| 09-02 06Z | 35.5°N 129.2°E | 965 hPa | **경남 상륙** |
| 09-02 12Z | 36.8°N 130.0°E | 980 hPa | 동해 진입, 약화 |

> 전처리기 실행 검증 완료: 백업(1~6)+최신(7) 병합 → `Model/fort.22` **7시점** 정상 생성,
> `Model/fort.8` 모의기간 **4.5일**(트랙 1.5 + 콜드스타트 3), `Model/fort.15` **DT=2초** 확인.

### 구동 방법

```bash
cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025\(0927\)/

# 입력은 이미 구축돼 있음:
#   ../NB/2025_90_NARITEST.txt  (통보문 백업, 트랙 1~10)
#   ./typhoon.in                (최신 통보, 트랙 11)

# 전체 파이프라인 수행
csh 01_runp_pre.csh                 # typhoon.in + NB → 바람장·fort.22·fort.15
csh 02_runp_model_padcirc.csh 240   # padcirc 모델 수행 (코어수 인자)
csh 03_runp_onlytide.csh            # 조위 분리
csh 04_runp_post.csh                # 가시화
```

> **통보문 백업 경로(NB) 처리**: 전처리기 바이너리에 운영서버 경로
> `/home/storm/GEOSR/2022_v53_geosr/NOTICE_BACKUP/` 가 하드코딩돼 있었다.
> 이 경로는 storm 유저 전용(700)이라 접근 불가 + 소스 재컴파일도 불가(서브루틴 소스 부재).
> → **바이너리의 경로 문자열을 동일 길이(47바이트)의 해커톤 폴더 경로
> `/data1/syjeong/2026/Inundation/02_Hackathon/NB/` 로 패치**하여 해커톤 폴더 안에서 자립 동작하도록 했다.
> 패치 재현 스크립트: [submit/assets/patch_notice_backup_path.sh](submit/assets/patch_notice_backup_path.sh)
> 원본 바이너리 백업: `Wind/mk_pre_fort15_22_26_MUN_v2.2.exe.orig`

> ⚠️ **omap 경로 잔존**: `fort.8` 에 `/home/storm/MIT/omap` 경로도 하드코딩돼 있다(바람장 관련).
> 모델 수행 시 이 경로 접근이 필요하면 동일 방식의 처리 또는 운영자 협의가 필요할 수 있다.

---

## 수행 환경

| 항목 | 내용 |
|------|------|
| 모델 | padcirc (ADCIRC, SWAN 미연동) |
| 실행파일 | `build/` 의 표준 ADCIRC 빌드 (Intel oneAPI MPI 2021.5.1) |
| 서버 | 83번 서버 (멀티노드 가능) |
| 코어 | **가변** — 상황에 맞게 조절 (스크립트 인자로 지정) |
| 격자 | `Model/fort.14` (`TEST-20130428`, FL grid) — **377,375 노드 / 716,981 요소** (저해상도, 수행시간 단축용) |
| 조도 | `Model/fort.13` — 저해상도 격자 전용 Manning's n (377,375 노드 일치) |
| 좌표계 | 경위도 (ICS=2, CPP 투영) |
| 시간간격 | **DT = 2 초** (저해상도 격자에 맞춰 1→2초 상향) |

> **수행시간 단축을 위한 환경 조정** (테스트베드용):
> - 격자: 고해상도(`build` 외 109만 요소) → **저해상도 `build/fort.14`(71만 요소)** 로 교체
> - 조도: 저해상도 격자 전용 `build/fort.13` 로 교체
> - 두 격자는 개방경계 구조가 동일(NOPE=3, NETA=154)하여 fort.15 조위강제 그대로 호환
> - 원본(고해상도)은 `*.bak_highres_*`, DT 1초 원본은 `fort_org.15.bak_dt1` 로 백업

### 가상태풍 테스트베드 기준 예상 수행 시간 (padcirc)

테스트베드 트랙(`typhoon.in`)은 약 **1.5일(36시간)** 길이이고, 전처리에 **콜드스타트 3일**이 내장되어
실제 모의 기간은 **약 4.5일(≈ 194,400 스텝 @ DT=2s)** 이다. 코어수별 추정:

| 코어 수 | 노드/코어 | 예상 벽시간(트랙 1.5일 + 콜드 3일) | 비고 |
|--------|----------|------------------------------|------|
| 60코어  | ≈ 6,290 | **약 3~5시간** | 코어 적을 때 |
| 120코어 | ≈ 3,145 | **약 1.5~3시간** | 권장 |
| 240코어 | ≈ 1,573 | **약 1~2시간**  | 통신부하 비중 증가 |

> **산출 근거**
> - 환경 조정으로 계산량 약 **1/4** 감소 (격자 0.65배 × DT 0.5배(스텝수 절반) × 모의 0.82배)
> - padcirc는 SWAN 미연동이라 시간스텝당 약 1.3~1.5배 빠름
> - 콜드스타트 3일은 전처리 소스에 하드코딩(`coldstart_day=3.0`) — 그대로 유지
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
│   │   ├── fort.14                      # ★ 사용 격자 (저해상도 FL grid, 37.7만 노드)
│   │   ├── fort.13                      # 저해상도 격자 전용 조도(Manning's n)
│   │   ├── fort_org.15                  # fort.15 템플릿 (DT=2초)
│   │   ├── *.bak_highres_* / *.bak_dt1  # 고해상도 격자·DT1초 원본 백업
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
