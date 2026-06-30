#!/bin/bash
# ───────────────────────────────────────────────
# 가상태풍 모델 수행 현황판
#   사용: bash status.sh   (언제든 실행)
# ───────────────────────────────────────────────
S="$(cd "$(dirname "$0")" && pwd)"
M="$S/Model"
ok="\033[32m✓\033[0m"; wait="\033[33m…대기\033[0m"; fail="\033[31m✗\033[0m"
line(){ printf "  %-30s %b\n" "$1" "$2"; }

echo "═══════════ 가상태풍 NARITEST 수행 현황 ═══════════"
date '+ %Y-%m-%d %H:%M:%S'
echo " 트랙 1.5일 + 콜드 3일 = 4.5일 모의 / DT 2s / 격자 37.7만노드 / node4,6,11=150코어"
echo ""

echo "── [01] PRE : 바람장 → fort.15 → hotstart 모델 ──"
[ -s "$M/fort.22" ] && line "바람장 fort.22 (NWS20)" "$ok" || line "바람장 fort.22" "$wait"
[ -s "$M/fort.15" ] && line "본모델 fort.15 (DT=$(sed -n '22p' "$M/fort.15" 2>/dev/null|awk '{print $1}'))" "$ok" || line "본모델 fort.15" "$wait"
[ -s "$M/hotstart/PE0000/fort.14" ] && line "hotstart adcprep 분할" "$ok" || line "hotstart 분할" "$wait"
[ -s "$M/fort.68" ] && line "hotstart 결과 fort.68" "$ok 완료" || line "hotstart fort.68" "$fail 미생성"
line "hotstart runtime" "$(cat "$M/hotstart/runtime.out" 2>/dev/null | tr '\n' '~')"
echo ""

echo "── [02] MAIN : 본모델 padcirc ──"
[ -s "$M/PE0000/fort.14" ] && line "본모델 adcprep 분할" "$ok" || line "본모델 분할" "$wait"
if [ -s "$M/fort.63" ]; then
  line "fort.63 전역수위 (생성중)" "$(du -h "$M/fort.63" 2>/dev/null|cut -f1)"
else
  line "fort.63 전역수위" "$wait"
fi
[ -s "$M/maxele.63" ] && line "maxele.63 (최대해수위)" "$ok" || line "maxele.63" "$wait"
line "main runtime" "$(cat "$M/runtime.out" 2>/dev/null | tr '\n' '~')"
echo ""

echo "── [03] ONLYTIDE : surge 분리 ──"
[ -s "$M/onlytide/PE0000/fort.14" ] && line "onlytide 분할" "$ok" || line "onlytide 분할" "$wait"
[ -s "$S/Post/only_surge.63" ] && line "only_surge.63" "$ok" || line "only_surge.63" "$wait"
echo ""

echo "── [04] POST : 가시화 ──"
if ls "$S/Post"/*.png "$S/Post"/*.tif "$S/Post"/*.jpg >/dev/null 2>&1; then line "그림 산출물" "$ok"; else line "그림" "$wait"; fi
echo ""

echo "── 실행중 프로세스 (본인) ──"
ps -ef | grep "$(whoami)" | grep -E "padcirc|adcprep|aswip|mpirun" | grep -v grep | awk '{printf "  %s ...\n", $8}' | head -3
[ $? ] || echo "  (없음)"
echo ""
echo "── 최근 로그 ──"
for lg in 01_pre.log 02_main.log 03_tide.log 04_post.log; do
  [ -s "$S/$lg" ] && { echo "  [$lg]"; tail -2 "$S/$lg" | sed 's/^/    /'; }
done
echo "═══════════════════════════════════════════════════"
