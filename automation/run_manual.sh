#!/bin/bash
###############################################################################
# run_manual.sh — GEO-ADCIRC(padcirc) 수동 순차 수행기
#
# 목적: 담당자가 소스 폴더에서 01→02→03→04 단계를 "순서대로, 손으로" 돌릴 때
#       단계 누락·순서 실수 없이 진행하도록 돕는다. (자동 감시 아님 — 사람이 직접 실행)
#       오케스트레이터 run_pipeline.sh와 달리 소스 복사를 하지 않고 **현재 폴더에서 그대로** 수행.
#
# 사용법 (소스 폴더에서 실행):
#   cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)/
#   /path/to/automation/run_manual.sh [코어수] [옵션]
#
# 옵션:
#   -n, --np <N>     padcirc 코어 수 (기본 120). 첫 위치인자로 줘도 됨.
#   -s, --step <N>   특정 단계만 수행 (1=pre, 2=model, 3=tide, 4=post). 생략 시 1→4 전부.
#   -y, --yes        단계 사이 확인 멈춤 없이 연속 수행 (기본은 각 단계 전 Enter 확인).
#   -h, --help       도움말.
#
# ※ 이 스크립트는 실제 모델(mpirun/padcirc)을 호출한다. 클러스터/입력파일이
#   준비된 소스 폴더에서만 실행할 것. 준비 전에는 실행하지 말 것.
###############################################################################
set -u

NP=120
ONLY_STEP=""
ASSUME_YES=0

# ---- 인자 파싱 -------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--np)   NP="$2"; shift 2;;
    -s|--step) ONLY_STEP="$2"; shift 2;;
    -y|--yes)  ASSUME_YES=1; shift;;
    -h|--help)
      grep -E '^#( |!)' "$0" | sed 's/^#//'; exit 0;;
    [0-9]*)    NP="$1"; shift;;          # 첫 위치인자 = 코어수
    *) echo "알 수 없는 옵션: $1"; exit 1;;
  esac
done

ts() { date '+%Y-%m-%d %H:%M:%S'; }
say() { echo "[$(ts)] $*"; }

# ---- 현재 폴더가 소스 폴더인지 점검 ---------------------------------------
need_files=(01_runp_pre.csh 03_runp_onlytide.csh 04_runp_post.csh)
missing=0
for f in "${need_files[@]}"; do
  [ -f "$f" ] || { echo "  ✗ 없음: $f"; missing=1; }
done
# 모델 스크립트는 padcirc 우선, 없으면 원본
if [ -f 02_runp_model_padcirc.csh ]; then
  MODEL_SCRIPT="02_runp_model_padcirc.csh"; MODEL_ARGS="$NP"
elif [ -f 02_runp_model.csh ]; then
  MODEL_SCRIPT="02_runp_model.csh"; MODEL_ARGS=""
  say "주의: padcirc 스크립트(02_runp_model_padcirc.csh)가 없어 원본 02_runp_model.csh 사용"
else
  echo "  ✗ 없음: 02_runp_model_padcirc.csh / 02_runp_model.csh"; missing=1
fi
if [ "$missing" = "1" ]; then
  echo ""
  echo "이 폴더는 소스 폴더가 아닌 것 같습니다. 아래에서 실행하세요:"
  echo "  cd /data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)/"
  exit 1
fi

# ---- 단계 정의 -------------------------------------------------------------
step_cmd() {   # 단계번호 → "스크립트 인자"
  case "$1" in
    1) echo "01_runp_pre.csh";;
    2) echo "$MODEL_SCRIPT $MODEL_ARGS";;
    3) echo "03_runp_onlytide.csh";;
    4) echo "04_runp_post.csh";;
  esac
}
step_name() {
  case "$1" in
    1) echo "01_PRE  — 바람장·hotstart·조위 전처리";;
    2) echo "02_MODEL— padcirc 본수행 (np=$NP)";;
    3) echo "03_TIDE — 조위 전용 수행";;
    4) echo "04_POST — FigureGen 가시화";;
  esac
}

confirm() {   # 단계 전 확인 (--yes면 통과)
  [ "$ASSUME_YES" = "1" ] && return 0
  printf "  ↳ 위 단계를 실행하려면 [Enter], 건너뛰려면 s, 중단하려면 q: "
  read -r ans </dev/tty
  case "$ans" in
    s|S) return 1;;
    q|Q) say "사용자 중단"; exit 0;;
    *)   return 0;;
  esac
}

run_one() {
  local n="$1"
  local cmd; cmd="$(step_cmd "$n")"
  echo "──────────────────────────────────────────────"
  say "[STEP $n] $(step_name "$n")"
  say "      실행 예정:  csh $cmd"
  if confirm; then
    say "      실행 시작..."
    csh $cmd
    local rc=$?
    if [ $rc -ne 0 ]; then say "      ✗ 실패 (rc=$rc) — 중단"; exit $rc; fi
    say "      ✓ 완료"
  else
    say "      (건너뜀)"
  fi
}

# ---- 메인 ------------------------------------------------------------------
echo "=============================================================="
say  "수동 순차 수행 — 모델: padcirc, 코어(NP): $NP"
say  "작업 폴더: $(pwd)"
[ -n "$ONLY_STEP" ] && say "단일 단계만 수행: STEP $ONLY_STEP"
echo "=============================================================="

if [ -n "$ONLY_STEP" ]; then
  run_one "$ONLY_STEP"
else
  for n in 1 2 3 4; do run_one "$n"; done
fi

echo "=============================================================="
say "수동 수행 종료. 산출물: maxele.63 → Post/ , 시계열 추출 결과 등"
echo "=============================================================="
