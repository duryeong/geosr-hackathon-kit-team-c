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

## 수행 환경 (현재 설정)

| 항목 | 내용 |
|------|------|
| 모델 | padcirc (ADCIRC 53.dev, SWAN 미연동) |
| 실행파일 | `build/` 의 표준 ADCIRC 빌드 (Intel oneAPI MPI 2021.5.1) |
| 노드/코어 | **node4:60 + node6:60 = 120코어** (수행 스크립트에 설정) |
| 격자 | `Model/fort.14` (`TEST-20130428`, FL grid) — **377,375 노드 / 716,981 요소** (저해상도) |
| 조도 | `Model/fort.13` — Manning's n (저해상도 격자 일치) |
| 좌표계 | 경위도 (ICS=2, CPP 투영) |
| 시간간격 | **DT = 2 초** |
| 바람 모델 | NWS=20 (GAHM) — ⚠️ 디버깅 중 (아래 "알려진 이슈") |
| 모의 기간 | **트랙 1.5일** (콜드스타트 제거, 바람장 시간정렬) |

> **수행시간 단축 환경 조정** (테스트베드용):
> - 격자: 고해상도(109만 요소) → 저해상도 `build/fort.14`(71만 요소). 개방경계 동일(NOPE=3,NETA=154)로 fort.15 조위강제 호환
> - 조도: 저해상도 전용 `build/fort.13`
> - DT 1→2초, 트랙 2.5→1.5일
> - 원본 백업: `*.bak_highres_*`, `fort_org.15.bak_dt1`

> **바람장 시간 정렬** (interpR 폭주 방지 핵심):
> - fort.15 WTIMINC 시작 = fort.22 첫 시각 = `2025-09-01 00시` (0점 정렬)
> - 콜드스타트 제거: `IHOT=0`, `RNDAY=1.5` → 콜드 구간(바람장 없는 3일)과 바람장의 시간 갭 제거

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

### 0. 환경 로드 (필수 — oneAPI MPI)

```bash
cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025\(0927\)/
source /appl/opt/oneapi/setvars.sh
export I_MPI_HYDRA_BOOTSTRAP=ssh
ulimit -s unlimited
ulimit -f 400000        # 로그 폭주(interpR 등) 디스크 보호
```

### 1. 시작 전 정리 (이전 잔재 제거)

```bash
# 내 모델 프로세스 정리 (comm 기반 — pkill -f 는 자기 명령까지 죽이니 금지)
ps -u $USER -o pid,comm | awk '/padcirc|mpirun|hydra/{print $1}' | xargs -r kill -9
# 분할(PE) 삭제
find . -maxdepth 3 -name "PE0*" -type d -exec rm -rf {} +
```

### 2. 전체 파이프라인

```bash
csh 01_runp_pre.csh              # 바람장 → fort.15 → hotstart 모델 (검증됨 ✓)
csh 02_runp_model_padcirc.csh    # 본모델 padcirc (node4+6=120) ⚠️ 바람장 이슈
csh 03_runp_onlytide.csh         # 조위 → surge 분리
csh 04_runp_post.csh             # 가시화
# 또는 한 번에:  bash run_all_padcirc.sh
```

> - 노드: `Runp_*.csh` 에 `node4:60 + node6:60` 설정됨. 변경 시 각 스크립트의 mpd.hosts 블록 수정.
> - adcprep 표준 2단계(`--partmesh` → `--prepall`). 구버전 `01~03_adcprep_992p`(wave서버 전용) 대체.
> - 백그라운드 수행 시 셸 종료에 안 죽도록 `nohup` 또는 독립 백그라운드로 실행.

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

---

## 실시간 모니터링 도구

```bash
bash flow.sh        # 파이프라인 흐름도 (3초마다 갱신, 단계별 ●완료/◐수행중/✗실패/○대기)
bash flow.sh --once # 1회만
bash status.sh      # 단계별 산출물 상세 현황
pbsnodes node4 node6 | grep -E "loadave|state"   # 노드 부하 (ssh 대신 — ssh 남발 금지)
```

> ⚠️ 노드 상태 확인은 `pbsnodes`로. `ssh node*` 를 반복하면 hang 세션이 쌓여 클러스터 ssh가 막히고,
> `psh compute uptime` 같은 정상 명령까지 영향받는다.

---

## 수행 기록 / 트러블슈팅 (재현용)

전체 파이프라인을 클러스터에서 돌리며 해결한 이슈들:

| 증상 | 원인 | 해결 |
|------|------|------|
| adcprep "station does not lie in grid" | 제주 등 일부 관측소가 저해상도 격자 밖 | fort.61(관측소) 제거, fort.63(전역) 1시간만 출력 |
| padcirc **SIGNAL 9 (Killed)** | fort.13(mannings) ↔ fort.15(chezy) **마찰 속성 불일치** | fort.15·생성스크립트 모두 `mannings_n_at_sea_floor` 로 통일 |
| ssh bootstrap 실패 (`cannot launch`) | ssh 일시 포화 (확인용 ssh 남발) | 회복 후 재시도, pbsnodes로 확인 |
| NOTICE_BACKUP 접근 불가 | `/home/storm` storm 유저 700 | 바이너리 경로를 해커톤 폴더로 패치([assets](submit/assets/patch_notice_backup_path.sh)) |
| 바람장 시간 갭 interpR | 콜드스타트(바람없음) ↔ 바람장 3일 갬 | 콜드 제거, WTIMINC=fort.22 첫시각 정렬 |

**검증 완료:** 01 PRE(바람장·fort.15·hotstart fort.68) ✅

---

## ⚠️ 알려진 이슈 (미해결): 본모델 태풍 바람장

- **증상:** 본모델 padcirc가 `ERROR: interpR failed in nws20get` 를 폭주 출력 (로그 GB급 → OOM/디스크)
- **원인:** padcirc(단독) GAHM 바람모델 ↔ fort.22 호환 문제
  | NWS | 결과 |
  |-----|------|
  | 320 (원본값) | interpR 폭주 — 파력(SWAN) 옵션, SWAN 없는 padcirc엔 부적합 |
  | 20 (GAHM) | interpR 폭주 — isotach 반경 보간 실패 (aswip가 `-m 4` 없이 호출돼 isotach 1개) |
  | 19 | fort.22 형식 불일치 (`input conversion error`) |
- **참고:** 원본(힌남노/종다리)은 **padc*swan*(SWAN 연동) + NWS=320** 으로 정상 — isotach 개수는 동일.
  즉 빌드(padcirc) ↔ fort.22 GAHM 호환이 핵심으로 추정.
- **다음 스텝(택1):**
  1. 원 모델 운영 팀원에게 *build/padcirc 단독 GAHM 설정(fort.15/fort.22/aswip)* 문의 — 가장 확실
  2. `Model/padcswan`(SWAN 연동) 방식으로 — 입력 구성 복잡
  3. 바람 없이(`NWS=0`) 조위만 일단 완주 → 파이프라인 동작·가시화 데모
- **재발 방지:** 수행 시 `ulimit -f` 로 로그 크기 제한 (디스크 보호)
