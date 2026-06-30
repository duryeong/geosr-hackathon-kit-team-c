#!/bin/bash
###############################################################################
# run_pipeline.sh — GEO-ADCIRC 태풍 침수모형 단일 케이스 오케스트레이터
#
# 레거시(check-tsw_hotstart.sh, 2022) 문제 복구판:
#   - 경로 하드코딩(/home/storm/2022) → 환경변수/인자로 분리
#   - 단계 호출 불일치(03=post 로 잘못 호출) → 실제 폴더 구조대로
#     01_pre → 02_model → 03_onlytide → 04_post 순서로 정정
#   - 클러스터(mpirun) 없을 때도 흐름을 검증하도록 DRY_RUN 지원
#
# 사용법:
#   SRC=<source폴더> RUN=<수행폴더> ./run_pipeline.sh <CASE_NAME>
#   DRY_RUN=1 로 두면 실제 모델 대신 단계만 시뮬레이션(로그만 남김).
#
# 예:
#   SRC="/data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)" \
#   RUN="/data1/syjeong/2026/Inundation/02_Hackathon/RUN" \
#   DRY_RUN=1 ./run_pipeline.sh 2026063012_TY01
###############################################################################
set -u

CASE="${1:-}"
SRC="${SRC:-}"
RUN="${RUN:-}"
NP="${NP:-120}"                   # padcirc 코어 수 (가변, 기본 120)
DRY_RUN="${DRY_RUN:-0}"           # 1이면 모델 실행 안 하고 흐름만 검증
LOG_DIR="${LOG_DIR:-$(pwd)/logs}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/pipeline_${CASE:-nocase}_$(date +%Y%m%d_%H%M%S).log"
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

die() { log "ERROR: $*"; exit 1; }

# ---- 입력 검증 -------------------------------------------------------------
[ -n "$CASE" ] || die "CASE 이름이 없습니다. 사용법: ./run_pipeline.sh <CASE_NAME>"
[ -n "$SRC" ]  || die "SRC(소스폴더) 환경변수가 필요합니다."
[ -n "$RUN" ]  || die "RUN(수행폴더) 환경변수가 필요합니다."
[ -d "$SRC" ]  || die "SRC 폴더가 없습니다: $SRC"

WORK="$RUN/$CASE"
log "=============================================================="
log "CASE      : $CASE"
log "SRC       : $SRC"
log "RUN(work) : $WORK"
log "MODEL     : padcirc (ADCIRC 단독, SWAN 미연동)"
log "NP(코어)  : $NP"
log "DRY_RUN   : $DRY_RUN"
log "=============================================================="

# ---- 작업폴더 준비: 소스 + 케이스 입력 복사 --------------------------------
mkdir -p "$WORK" || die "작업폴더 생성 실패: $WORK"
if [ "$DRY_RUN" = "1" ]; then
  log "[stage 0] (dry) 소스/케이스 입력 복사 시뮬레이션"
else
  log "[stage 0] 소스 복사: $SRC/* → $WORK"
  cp -rf "$SRC/." "$WORK/" || die "소스 복사 실패"
fi

cd "$WORK" 2>/dev/null || { [ "$DRY_RUN" = "1" ] && cd "$SRC" || die "작업폴더 진입 실패"; }

# ---- 클러스터 가용성 점검 --------------------------------------------------
have_mpi=0
command -v mpirun >/dev/null 2>&1 && have_mpi=1
if [ "$DRY_RUN" != "1" ] && [ "$have_mpi" = "0" ]; then
  die "mpirun 미발견 — 실제 모델은 클러스터(wave01~28)에서만 수행됩니다. 테스트는 DRY_RUN=1 로 실행하세요."
fi

# ---- 단계 실행기 -----------------------------------------------------------
run_step() {
  local name="$1"; shift
  local script="$1"; shift
  local args="$*"
  log "----- [$name] 시작: $script $args -----"
  if [ "$DRY_RUN" = "1" ]; then
    log "      (dry) csh $script $args  ← 실제 실행 생략"
    sleep 1
  else
    [ -f "$script" ] || die "[$name] 스크립트 없음: $script"
    csh "$script" $args >>"$LOG" 2>&1 || die "[$name] 실행 실패 (로그: $LOG)"
  fi
  log "----- [$name] 완료 -----"
}

# ---- 파이프라인 (정정된 순서 + padcirc 전환 반영) -------------------------
#   모델 본수행: padcswan(02_runp_model.csh) → padcirc(02_runp_model_padcirc.csh <코어수>)
run_step "01_PRE  (바람장·hotstart·조위 전처리)" "01_runp_pre.csh"
run_step "02_MODEL(padcirc 본수행, np=$NP)"      "02_runp_model_padcirc.csh" "$NP"
run_step "03_TIDE (조위 전용 수행)"               "03_runp_onlytide.csh"
run_step "04_POST (FigureGen 가시화)"             "04_runp_post.csh"

log "=============================================================="
log "PIPELINE DONE — CASE: $CASE"
log "산출물(예): maxele.63 → Post/, FigureGen 결과물"
log "다음 단계(③④⑤): 가시화 결과 → 의사결정 에이전트 → 보고서 (별도 모듈)"
log "로그 파일: $LOG"
log "=============================================================="
