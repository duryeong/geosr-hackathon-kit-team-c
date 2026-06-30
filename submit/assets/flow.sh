#!/bin/bash
# ───────────────────────────────────────────────────────────────
#  가상태풍 모델 수행 실시간 흐름도
#    사용:  bash flow.sh         (3초마다 자동 갱신, Ctrl+C 종료)
#           bash flow.sh --once  (1회만 출력)
# ───────────────────────────────────────────────────────────────
S="$(cd "$(dirname "$0")" && pwd)"
M="$S/Model"
ME="$(whoami)"

C0='\033[0m'; CB='\033[1m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; D='\033[90m'

# 단계 상태 판정: echo "DONE|RUN|WAIT|FAIL"
phase_state(){
  local done_file="$1" runtime="$2" log="$3"
  if [ -s "$done_file" ]; then echo DONE; return; fi
  if [ -n "$runtime" ] && [ -f "$runtime" ]; then
    # runtime 시작됐는데 산출물 없음 → 로그에 에러면 FAIL, 아니면 RUN
    if [ -s "$log" ] && grep -qiE "SIGNAL: 9|MPI_Abort|ERROR:|does not lie|terminat" "$log" 2>/dev/null; then echo FAIL; else echo RUN; fi
    return
  fi
  echo WAIT
}

badge(){ case "$1" in
  DONE) printf "${G}● 완료${C0}";;
  RUN)  printf "${Y}◐ 수행중${C0}";;
  FAIL) printf "${R}✗ 실패${C0}";;
  *)    printf "${D}○ 대기${C0}";;
esac; }

box(){ # $1=label $2=state
  local col=$D; case "$2" in DONE) col=$G;; RUN) col=$Y;; FAIL) col=$R;; esac
  printf "${col}┌────────┐${C0}\n${col}│${C0}${CB}%-8s${C0}${col}│${C0}\n${col}└────────┘${C0}\n" "$1"
}

draw(){
  printf '\033[2J\033[H'   # TERM 무관 화면 클리어
  # 실행중 프로세스
  local running cur
  running=$(ps -ef | grep "$ME" | grep -E "padcirc|adcprep|aswip" | grep -v grep | wc -l)
  cur=$(ps -ef | grep "$ME" | grep -E "padcirc|adcprep|aswip" | grep -v grep | grep -oE "padcirc|adcprep|aswip" | head -1)

  # 단계 상태
  local s1 s2 s3 s4
  s1=$(phase_state "$M/fort.68" "$M/hotstart/runtime.out" "$M/hotstart/hs_retry3.log")
  s2=$(phase_state "$M/maxele.63" "$M/runtime.out" "$S/02_main.log")
  s3=$(phase_state "$S/Post/only_surge.63" "$M/onlytide/runtime.out" "$S/03_tide.log")
  s4=WAIT; ls "$S/Post"/*.png "$S/Post"/*.tif "$S/Post"/*.jpg >/dev/null 2>&1 && s4=DONE

  echo -e "${CB}══════════ 가상태풍 NARITEST · 모델 수행 흐름 (실시간) ══════════${C0}"
  echo -e " $(date '+%Y-%m-%d %H:%M:%S')   격자 37.7만노드 · DT 2s · 모의 4.5일 · node6+11=90코어"
  echo ""

  # ── 흐름도 (가로 박스 + 화살표 + 상태) ──
  arrow(){ [ "$1" = DONE ] && printf "${G}══▶${C0}" || printf "${D}──▶${C0}"; }
  paste -d' ' \
    <(box "01 PRE" $s1) <(printf "   \n %b\n   \n" "$(arrow $s1)") \
    <(box "02 MAIN" $s2) <(printf "   \n %b\n   \n" "$(arrow $s2)") \
    <(box "03 TIDE" $s3) <(printf "   \n %b\n   \n" "$(arrow $s3)") \
    <(box "04 POST" $s4)
  printf "  %-9s    %-9s    %-9s    %-9s\n" "$(badge $s1)" "$(badge $s2)" "$(badge $s3)" "$(badge $s4)"
  echo ""

  # ── 단계별 상세 ──
  sym(){ [ -s "$1" ] && printf "${G}✓${C0}" || printf "${D}·${C0}"; }
  echo -e "${B}[01 PRE]${C0} 바람장→fort.15→hotstart"
  printf "   바람장 fort.22 %b   본모델 fort.15 %b(DT=%s)   hotstart fort.68 %b\n" \
    "$(sym "$M/fort.22")" "$(sym "$M/fort.15")" "$(sed -n '22p' "$M/fort.15" 2>/dev/null|awk '{print $1}')" "$(sym "$M/fort.68")"
  echo -e "${B}[02 MAIN]${C0} 본모델 padcirc → 전역수위"
  printf "   분할 PE %b   fort.63 %b%s   maxele.63 %b\n" \
    "$([ -s "$M/PE0000/fort.14" ] && printf "${G}✓${C0}" || printf "${D}·${C0}")" \
    "$([ -s "$M/fort.63" ] && printf "${G}✓${C0}" || printf "${D}·${C0}")" \
    "$([ -s "$M/fort.63" ] && echo " ($(du -h "$M/fort.63" 2>/dev/null|cut -f1))" || echo "")" \
    "$(sym "$M/maxele.63")"
  echo -e "${B}[03 TIDE]${C0} 조위 → surge 분리"
  printf "   분할 PE %b   only_surge.63 %b\n" \
    "$([ -s "$M/onlytide/PE0000/fort.14" ] && printf "${G}✓${C0}" || printf "${D}·${C0}")" "$(sym "$S/Post/only_surge.63")"
  echo -e "${B}[04 POST]${C0} 가시화"
  printf "   그림 %b\n" "$([ "$s4" = DONE ] && printf "${G}✓${C0}" || printf "${D}·${C0}")"
  echo ""

  # ── 실행 정보 ──
  if [ "$running" -gt 0 ]; then
    echo -e " ${Y}▶ 실행중:${C0} ${cur} (프로세스 ${running}개)  runtime: $(cat "$M/hotstart/runtime.out" 2>/dev/null|head -1) ~ 진행"
  else
    echo -e " ${D}▷ 실행중 프로세스 없음${C0}"
  fi
  # 최근 로그 (가장 최근 수정된 로그)
  local lastlog
  lastlog=$(ls -t "$S"/*.log "$M"/hotstart/*.log "$M"/onlytide/*.log 2>/dev/null | head -1)
  if [ -n "$lastlog" ]; then
    echo -e " ${D}최근로그 ($(basename "$lastlog")):${C0}"
    tail -2 "$lastlog" 2>/dev/null | sed 's/^/   /'
  fi
  echo -e "${D}──────────────────────────────────────────────────────────────${C0}"
  [ "$1" != "--once" ] && echo " (3초마다 갱신 · Ctrl+C 종료)"
}

if [ "$1" = "--once" ]; then draw --once; else
  trap 'echo; echo "종료."; exit 0' INT
  while true; do draw; sleep 3; done
fi
