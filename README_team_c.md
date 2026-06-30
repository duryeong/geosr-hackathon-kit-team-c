# C팀 — 태풍 발생부터 의사결정 보고서 작성까지 전 과정 자동화

> 26년 예보사업부 AI·AX 해커톤 | 2026.6.30(화)~7.1(수) | 엘리스랩 부산센터

## 프로젝트 개요

태풍 통보문 수신 → 수치모형(GEO-ADCIRC) 자동 수행 → 결과 가시화 → 의사결정 에이전트 기반 보고서 작성까지,
담당자가 수작업으로 개입하던 전 과정을 통합 자동화 체계로 구현한다.

```
[태풍 통보문 수신]
     ↓  crontab (5분 주기 감시)
[수치모형 자동 수행]  ← ADCIRC + SWAN 연동
     ↓  pre → model → post
[결과 가시화]         ← FigureGen / GMT 자동 생성
     ↓
[의사결정 에이전트]   ← AI 기반 위험도 판단
     ↓
[보고서 자동 작성]
```

상세 기획은 `제안자료_v3.pptx` 참고.

---

## 작업 폴더 위치 (서버 공용)

```
/data1/syjeong/2026/Inundation/02_Hackathon/
├── 제안자료_v3.pptx                     # 프로젝트 제안 발표자료 (상세 기획 참고)
├── TY_scripts(Crontab)/                 # 태풍 통보문 수집 크론탭 스크립트
│   └── check-tsw_hotstart.sh           # 메인 감시 스크립트 (5분 주기 실행)
├── source_GEO_Edit_2025(0927)/          # GEO-ADCIRC 모델 수행 자동화 소스코드
│   ├── 01_runp_pre.csh                 # 전처리 (바람장·조화분조·hotstart 생성)
│   ├── 02_runp_model.csh               # 모델 본수행 (ADCIRC+SWAN)
│   ├── 03_runp_onlytide.csh            # 조위만 수행 (폭풍해일 산출용)
│   ├── 04_runp_post.csh                # 후처리 (FigureGen 가시화)
│   ├── 05_remove.sh                    # 임시파일 정리
│   ├── Wind/                           # 바람장 생성 스크립트·입력파일
│   ├── hotstart/                       # Hotstart 초기장 생성
│   ├── onlytide/                       # 조위 전용 수행
│   ├── Model/                          # ADCIRC 실행파일·격자파일(fort.13/14)
│   └── Post/                           # 후처리 실행파일·FigureGen 설정파일
└── geosr-hackathon-kit-team-c/         # 이 저장소 (해커톤 킷 + 작업로그)
```

---

## 크론탭 설정 방법

태풍 통보문 감시 스크립트를 5분 주기로 실행하도록 크론탭에 등록한다.

```bash
# 크론탭 편집
crontab -e

# 아래 한 줄 추가
*/5 * * * * /data1/syjeong/2026/Inundation/02_Hackathon/TY_scripts\(Crontab\)/check-tsw_hotstart.sh
```

스크립트 실행 전 사전 준비:

```bash
# 실행 권한 확인
chmod 755 /data1/syjeong/2026/Inundation/02_Hackathon/TY_scripts\(Crontab\)/check-tsw_hotstart.sh

# 케이스 카운터 초기화
echo "1" > /tmp/CASE_CNT
touch /tmp/CASE2
```

---

## 모델 수동 수행 (테스트용)

```bash
cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025\(0927\)/

csh 01_runp_pre.csh       # 전처리
csh 02_runp_model.csh     # 본수행
csh 03_runp_onlytide.csh  # 조위 수행
csh 04_runp_post.csh      # 후처리·가시화
```

---

## 팀원 작업폴더 접근

서버 내 팀원이라면 아래 경로로 직접 접근 가능:

```
/data1/syjeong/2026/Inundation/02_Hackathon/
```

이 저장소(해커톤 킷) 클론:

```bash
git clone git@github.com:duryeong/geosr-hackathon-kit-team-c.git
cd geosr-hackathon-kit-team-c
```

Claude Code에서 작업 시 이 폴더에서 `claude` 실행 → `CLAUDE.md` 자동 로드.

---

## 제출 구조

```
submit/
├── PROCESS_LOG_team_c_SY.md    # 정수영 작업 로그
├── PROCESS_LOG_team_c_MS.md    # 팀원 작업 로그
├── BEFORE_AFTER.md             # 수작업 → 자동화 효과 측정
├── assets/                     # 재사용 프롬프트·스킬
└── evidence/timestamps.txt     # 자동 타임스탬프 증빙
```
