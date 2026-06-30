#!/bin/bash
###############################################################################
# setup_run.sh — GEO-ADCIRC(padcirc) 수행 전 입력/환경 세팅 + 점검
#
# "수동 수행이 가능하도록" 소스 폴더를 준비한다.
# 분석으로 확인된 수행 블로커를 점검(--check)하거나 실제로 보정(--apply)한다.
#
#   확인된 블로커
#   (1) Wind/typhoon.in 누락 — hotstart/onlytide/Model 실행파일이 ../Wind/typhoon.in 을
#       읽는데 파일이 없음. 루트 typhoon.in 을 Wind/ 로 복사해야 함.
#   (2) Run_NDMI_wind.csh 의 'cp -f ../typhoon.in ./' 줄이 주석 → 매 수행 시 (1)이 재발.
#   (3) Model/hotstart/padcirc, Model/onlytide/padcirc 실행권한 없음.
#   (참고-미보정) Model/hotstart·onlytide 수행스크립트는 아직 레거시 992코어 고정
#       (01~03_adcprep_992p, np=992, wave01~28). 83번 서버 가변코어로 쓰려면
#       padcirc 전환 필요 — 모델 담당(SY)과 협의. 이 스크립트는 손대지 않음.
#
# 사용법:
#   ./setup_run.sh --check            # 점검만 (변경 없음)  ← 기본
#   ./setup_run.sh --apply            # 보정 적용 (백업 후)
#   SRC=<소스폴더> ./setup_run.sh ...  # 소스 폴더 지정(기본: 아래 DEFAULT_SRC)
#
# ※ 모델은 실행하지 않는다. 입력/권한만 준비한다.
###############################################################################
set -u

DEFAULT_SRC="/data1/syjeong/2026/Inundation/02_Hackathon/source_GEO_Edit_2025(0927)"
SRC="${SRC:-$DEFAULT_SRC}"
MODE="check"
case "${1:-}" in
  --apply) MODE="apply";;
  --check|"") MODE="check";;
  -h|--help) grep -E '^#( |!)' "$0" | sed 's/^#//'; exit 0;;
  *) echo "알 수 없는 옵션: $1 (--check | --apply)"; exit 1;;
esac

ok=0; warn=0; fail=0
P(){ echo "  ✅ $*"; ok=$((ok+1)); }
W(){ echo "  ⚠️  $*"; warn=$((warn+1)); }
F(){ echo "  ❌ $*"; fail=$((fail+1)); }

[ -d "$SRC" ] || { echo "소스 폴더 없음: $SRC"; exit 1; }
echo "=============================================================="
echo " setup_run ($MODE)  —  SRC: $SRC"
echo "=============================================================="

# ── 활성 태풍 표시 ──────────────────────────────────────────────
if [ -f "$SRC/typhoon.in" ]; then
  echo " 활성 태풍(typhoon.in 1행): $(head -1 "$SRC/typhoon.in")"
else
  F "루트 typhoon.in 없음 — 수행할 태풍 입력이 없습니다. (먼저 typhoon.in 준비 필요)"
fi
echo "--------------------------------------------------------------"

STAMP="$(date +%Y%m%d_%H%M%S)"

# ── (1)+(2) Wind/typhoon.in ────────────────────────────────────
echo "[1] Wind/typhoon.in (하위 실행파일이 ../Wind/typhoon.in 참조)"
if [ -f "$SRC/Wind/typhoon.in" ]; then
  if diff -q "$SRC/typhoon.in" "$SRC/Wind/typhoon.in" >/dev/null 2>&1; then
    P "존재하며 루트와 동일"
  else
    W "존재하나 루트 typhoon.in 과 내용 다름 (태풍 불일치 가능)"
    if [ "$MODE" = "apply" ]; then
      cp -f "$SRC/Wind/typhoon.in" "$SRC/Wind/typhoon.in.bak_$STAMP"
      cp -f "$SRC/typhoon.in" "$SRC/Wind/typhoon.in" && P "→ 루트값으로 갱신(백업함)"
    fi
  fi
else
  F "없음 — hotstart/onlytide/Model 단계가 입력을 못 찾음"
  if [ "$MODE" = "apply" ]; then
    cp -f "$SRC/typhoon.in" "$SRC/Wind/typhoon.in" && P "→ 생성함 (루트 복사)"
  fi
fi

echo "[2] Run_NDMI_wind.csh 의 typhoon.in 복사줄"
WCSH="$SRC/Wind/Run_NDMI_wind.csh"
if grep -qE '^[[:space:]]*cp -f \.\./typhoon\.in \./' "$WCSH" 2>/dev/null; then
  P "복사줄 활성화돼 있음 (매 수행 시 Wind/typhoon.in 동기화)"
elif grep -qE '^[[:space:]]*#cp -f \.\./typhoon\.in \./' "$WCSH" 2>/dev/null; then
  W "복사줄이 주석 처리됨 → 매 수행 시 Wind/typhoon.in 재누락 위험"
  if [ "$MODE" = "apply" ]; then
    cp -p "$WCSH" "$WCSH.bak_$STAMP"
    sed -i 's|^\([[:space:]]*\)#cp -f \.\./typhoon\.in \./|\1cp -f ../typhoon.in ./|' "$WCSH" \
      && P "→ 주석 해제(백업함)"
  fi
else
  W "복사줄을 찾지 못함 — 수동 확인 필요"
fi

# ── (3) 실행권한 ───────────────────────────────────────────────
echo "[3] padcirc 실행권한"
for f in Model/padcirc Model/hotstart/padcirc Model/onlytide/padcirc; do
  if [ -f "$SRC/$f" ]; then
    if [ -x "$SRC/$f" ]; then P "$f 실행가능"
    else
      W "$f 실행권한 없음"
      [ "$MODE" = "apply" ] && chmod +x "$SRC/$f" && P "→ chmod +x $f"
    fi
  else
    F "$f 없음"
  fi
done

# ── (참고) 하위 992코어 레거시 경고 ────────────────────────────
echo "[4] (참고) hotstart/onlytide 수행스크립트 코어 방식"
for s in Model/hotstart/Runp_hotstart.csh Model/onlytide/Runp_onlytide.csh; do
  if grep -q "np=992" "$SRC/$s" 2>/dev/null; then
    W "$s 가 레거시 992코어 고정 → 83번 서버 가변코어 미대응(모델담당 협의 필요, 본 스크립트 미보정)"
  fi
done

echo "=============================================================="
echo " 결과: ✅ $ok  ⚠️ $warn  ❌ $fail   (모드: $MODE)"
[ "$MODE" = "check" ] && echo " 보정하려면: ./setup_run.sh --apply"
echo "=============================================================="
