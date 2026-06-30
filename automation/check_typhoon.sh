#!/bin/bash
###############################################################################
# check_typhoon.sh — 태풍 통보문(신규 케이스) 감시 → 파이프라인 자동 기동
#
# 레거시 check-tsw_hotstart.sh(2022) 현대화판:
#   - /home/storm/2022 하드코딩 제거 → 환경변수(ENV)로 분리
#   - /tmp/CASE_CNT,CASE1,CASE2 (재부팅·tmp정리에 취약) →
#     영속 상태파일(STATE_FILE)에 '처리완료 케이스 목록'을 누적 기록
#   - 단계 호출은 run_pipeline.sh에 위임(순서 정정: pre→model→onlytide→post)
#
# crontab 등록:
#   */5 * * * * /path/to/automation/check_typhoon.sh >> /path/to/automation/logs/monitor.log 2>&1
#
# 필수 ENV (없으면 아래 기본값 사용 — 운영 시 본인 경로로 수정):
#   DATA_DIR : 기상청 태풍 통보문이 케이스폴더(2*)로 떨어지는 위치
#   RUN_DIR  : 모델 수행 폴더
#   SRC_DIR  : GEO-ADCIRC 소스 폴더
###############################################################################
set -u

BASE="${BASE:-/data1/syjeong/2026/Inundation/02_Hackathon}"
DATA_DIR="${DATA_DIR:-$BASE/KMA}"                       # 통보문 수신 폴더 (운영 시 실제 경로로)
RUN_DIR="${RUN_DIR:-$BASE/RUN}"
SRC_DIR="${SRC_DIR:-$BASE/source_GEO_Edit_2025(0927)}"
STATE_FILE="${STATE_FILE:-$BASE/automation_state/processed_cases.txt}"
NP="${NP:-120}"                                        # padcirc 코어 수 (가변)
DRY_RUN="${DRY_RUN:-0}"

HERE="$(cd "$(dirname "$0")" && pwd)"
ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] [monitor] $*"; }

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

[ -d "$DATA_DIR" ] || { log "DATA_DIR 없음(통보문 수신 폴더 미설정): $DATA_DIR"; exit 0; }

# 신규 케이스(폴더명 2*로 시작) 중 아직 미처리인 가장 오래된 1건을 처리
NEW_CASE=""
while IFS= read -r c; do
  cname="$(basename "$c")"
  if ! grep -qxF "$cname" "$STATE_FILE"; then
    NEW_CASE="$cname"
    break
  fi
done < <(find "$DATA_DIR" -maxdepth 1 -mindepth 1 -type d -name '2*' | sort)

if [ -z "$NEW_CASE" ]; then
  log "신규 케이스 없음 (모두 처리됨)"
  exit 0
fi

log "신규 케이스 감지: $NEW_CASE → 파이프라인 기동"

SRC="$SRC_DIR" RUN="$RUN_DIR" NP="$NP" DRY_RUN="$DRY_RUN" \
  bash "$HERE/run_pipeline.sh" "$NEW_CASE"
rc=$?

if [ $rc -eq 0 ]; then
  echo "$NEW_CASE" >> "$STATE_FILE"
  log "케이스 처리 완료 → 상태파일 기록: $NEW_CASE"
else
  log "케이스 처리 실패(rc=$rc) — 상태파일에 기록하지 않음(다음 주기 재시도)"
fi
