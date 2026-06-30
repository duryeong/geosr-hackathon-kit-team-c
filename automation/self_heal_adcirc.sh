#!/bin/bash
###############################################################################
# self_heal_adcirc.sh — ADCIRC(sample_run) 자가치유 순환구조 오케스트레이터
#
# 대상은 sample_run 한 폴더뿐. mpi.sh 를 (버그 고친 형태로) 돌려보고
# 4중 성공게이트로 "진짜 완주"를 판정한다. 실패면 원인을 분류·발췌해
# claude(소넷)에게 넘기고, 소넷이 fort.15만 고친다. 회당 사용자 수동승인.
#
# 역할 분리:
#   - 이 스크립트(결정론) : 실행 / stdout+stderr 분리포착 / 게이트 / 실패분류·발췌
#                           / 샌드박스 호출 / 해시가드 / diff제시 / 일시정지
#   - 소넷(claude -p)     : 원인 판단 + fort.15 수정 (안정성 파라미터 / NWP 속성명)
#   ※ 이 스크립트는 "어떤 파라미터를 어떻게 고쳐라"를 절대 하드코딩하지 않는다.
#
# 모드:
#   run      새 세션 시작 → 1사이클 수행 → (실패시 소넷수정 적용) → diff제시 → 정지
#   approve  현재 세션에서 다음 사이클 수행(직전 소넷수정을 승인하고 재실행)
#   revert   직전 소넷수정을 백업에서 되돌리고 세션 종료
#   status   현재 세션 상태 출력
#
# 사용 예:
#   ./self_heal_adcirc.sh run
#   ./self_heal_adcirc.sh approve
#   ./self_heal_adcirc.sh revert
#
# 환경변수(선택):
#   RUN_DIR    대상 폴더 (기본 sample_run)
#   MAX_WALL   사이클당 mpirun 타임아웃 초 (기본 1800)
#   MAX_ITER   세션 최대 사이클 (기본 8)
#   NP         코어 수 (기본 120)
#   MODEL      소넷 모델 id (기본 claude-sonnet-4-6)
#   SKIP_NODE_PROBE=1  노드 ssh 프로브 생략
###############################################################################
set -u

# ── 설정 ──────────────────────────────────────────────────────────────────
RUN_DIR="${RUN_DIR:-/data1/syjeong/2026/Inundation/02_Hackathon/sample_run}"
SETVARS="/appl/opt/oneapi/setvars.sh"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGROOT="$KIT_DIR/logs/selfheal"
MAX_WALL="${MAX_WALL:-1800}"
MAX_ITER="${MAX_ITER:-8}"
NP="${NP:-120}"
MODEL="${MODEL:-claude-sonnet-4-6}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# fort.15 안에서 소넷이 바꿔도 되는 줄(그 외는 가드가 되돌린다)
#   14,15 = NWP 절점속성명 / 21=TAU0 / 22=DT / 26=DRAMP / 27=A00 B00 C00
ALLOWED_LINES="14 15 21 22 26 27"
RNDAY_LINE=25   # 불가침

# 소넷 호출 없이 사용자에게 넘기는 환경/구성 오류 분류
ENV_FAILTYPES="ADCPREP_FAIL MPI_ABORT RUN_TIMEOUT"

MANUAL="https://adcirc.org/home/documentation/users-manual-v53/input-file-descriptions/model-parameter-and-periodic-boundary-condition-file-fort-15/"
MANUAL2="https://adcirc.org/home/documentation/users-manual-v53/parameter-definitions/"
PRIORITY_DOC="${PRIORITY_DOC:-$KIT_DIR/CHECK_PRIORITY.md}"  # 팀 진단 우선순위(JM) — 소넷 권위 가이드

C0='\033[0m'; CB='\033[1m'; CG='\033[32m'; CR='\033[31m'; CY='\033[33m'
say(){ printf "%b\n" "$*"; }
hr(){  printf '%.0s─' {1..70}; echo; }
die(){ say "${CR}[FATAL]${C0} $*" >&2; exit 9; }

# ── 누적 수정저널 (사람이 읽기 쉬운 "왜 오류·무엇을·왜 고침" 기록) ──────────
JOURNAL(){ [ -n "${SESSION:-}" ] && printf '%b\n' "$*" >> "$LOGROOT/$SESSION/FIX_JOURNAL.md"; }

MODE="${1:-status}"

[ -d "$RUN_DIR" ] || die "RUN_DIR 없음: $RUN_DIR"
mkdir -p "$LOGROOT" || die "로그루트 생성 실패: $LOGROOT"
CUR_PTR="$LOGROOT/current_session"

# ── 환경 준비(mpirun) ───────────────────────────────────────────────────────
ensure_mpi(){
  # setvars.sh 는 미정의 변수를 참조 → set -u 면 즉시종료. source 구간만 -u 해제.
  set +u
  # shellcheck disable=SC1090
  source "$SETVARS" >/dev/null 2>&1 || true
  set -u
  command -v mpirun >/dev/null 2>&1 || die "setvars 후에도 mpirun 없음 ($SETVARS 확인)"
}

# ── 노드 프로브(소프트): 다운이면 NODE_WARN=1 (FATAL 아님) ──────────────────
NODE_WARN=0
probe_nodes(){
  [ "${SKIP_NODE_PROBE:-0}" = "1" ] && return 0
  local h
  for h in $(cut -d: -f1 "$RUN_DIR/machine" 2>/dev/null | sort -u); do
    [ -z "$h" ] && continue
    if ! timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" true 2>/dev/null; then
      say "${CY}[WARN]${C0} 노드 미응답: $h (mpirun 실패 시 인프라 원인일 수 있음)"
      NODE_WARN=1
    fi
  done
}

# ── 세션 상태 ──────────────────────────────────────────────────────────────
load_state(){
  SESSION=""; ITER=0; LAST_FAILTYPE=""; LAST_BACKUP=""; RESOLVED=""
  [ -f "$CUR_PTR" ] && SESSION="$(cat "$CUR_PTR")"
  STATE="$LOGROOT/$SESSION/state.env"
  if [ -n "$SESSION" ] && [ -f "$STATE" ]; then
    # shellcheck disable=SC1090
    source "$STATE"
  fi
}
save_state(){
  cat > "$STATE" <<EOF
SESSION=$SESSION
ITER=$ITER
LAST_FAILTYPE=$LAST_FAILTYPE
LAST_BACKUP=$LAST_BACKUP
RESOLVED=$RESOLVED
EOF
}

# ── 성공게이트 (4조건 전부) — 0=PASS ────────────────────────────────────────
GATE_REASON=""
success_gate(){
  local out="$CYC/stdout.log" err="$CYC/stderr.log"
  GATE_REASON=""
  # (1) MPI 완료마커 (필요조건)
  tail -n 80 "$out" 2>/dev/null | grep -Eq 'MPI terminated with Status = *0' \
    || { GATE_REASON="MPI 완료마커 없음"; return 11; }
  # (2) stdout/stderr 양쪽에 발산토큰 없음
  if grep -Eiq 'ErrorElev|Elevation\.gt|ADCIRC stopping|NaN|Infinity|\*\* *ERROR' "$out" "$err" 2>/dev/null; then
    GATE_REASON="발산/에러 토큰 검출(stdout 또는 stderr)"; return 12
  fi
  # (3) RNDAY 완주: last_ts * |DT| >= RNDAY*86400 - 1
  local dt rnday last_ts simsec needsec
  dt="$(awk 'NR==22{gsub(/[^0-9.eE+-]/,"",$1);print ($1<0?-$1:$1)}' "$RUN_DIR/fort.15")"
  rnday="$(awk 'NR==25{print $1+0}' "$RUN_DIR/fort.15")"
  last_ts="$(grep -oE 'TIME STEP[ =]+[0-9]+' "$out" 2>/dev/null | grep -oE '[0-9]+$' | tail -1)"
  last_ts="${last_ts:-0}"
  simsec="$(awk -v t="$last_ts" -v d="$dt" 'BEGIN{print t*d}')"
  needsec="$(awk -v r="$rnday" 'BEGIN{print r*86400}')"
  awk -v s="$simsec" -v n="$needsec" 'BEGIN{exit !((s+0)>=(n-1))}' \
    || { GATE_REASON="RNDAY 미완주 (sim ${simsec}s / 목표 ${needsec}s, last_ts=$last_ts, DT=$dt)"; return 13; }
  # (4) maxele.63 생성 + 유한
  local mx=""
  [ -f "$RUN_DIR/maxele.63" ] && mx="$RUN_DIR/maxele.63"
  [ -z "$mx" ] && [ -f "$RUN_DIR/maxele.63.nc" ] && mx="$RUN_DIR/maxele.63.nc"
  [ -n "$mx" ] || { GATE_REASON="maxele.63 미생성"; return 14; }
  if [ "${mx##*.}" = "63" ]; then
    grep -Eiq 'nan|infinity' "$mx" && { GATE_REASON="maxele.63 비유한(NaN/Inf)"; return 15; }
  fi
  return 0
}

# ── 실패 분류 + 컨텍스트 발췌 (수정판단 없음) ───────────────────────────────
classify(){
  local out="$CYC/stdout.log" err="$CYC/stderr.log"
  LAST_TS="$(grep -oE 'TIME STEP[ =]+[0-9]+' "$out" 2>/dev/null | grep -oE '[0-9]+$' | tail -1)"
  LAST_TS="${LAST_TS:-0}"
  ELMAX="$(grep -oiE 'ELMAX[ =]+[-0-9.eE+]+' "$out" "$err" 2>/dev/null | grep -oE '[-0-9.eE+]+$' | tail -1)"
  INCLUDE_F13=0

  if [ "${adcprep_rc:-0}" -ne 0 ]; then FAILTYPE=ADCPREP_FAIL; return; fi
  if [ "${mpi_rc:-0}" = "124" ]; then FAILTYPE=RUN_TIMEOUT; return; fi
  if grep -Eiq 'nodal attribute|attribute.*not.*found|not.*found.*(fort\.13|unit *13)|fort\.13.*not.*found' "$out" "$err" 2>/dev/null; then
    FAILTYPE=NODAL_ATTR_NOT_FOUND; INCLUDE_F13=1; return
  fi
  if grep -Eiq 'ErrorElev|Elevation\.gt|ADCIRC stopping' "$out" "$err" 2>/dev/null; then FAILTYPE=ELEV_BLOWUP; return; fi
  if grep -Eiq 'NaN|Infinity' "$out" "$err" 2>/dev/null; then FAILTYPE=NAN; return; fi
  if [ "${mpi_rc:-0}" -ne 0 ] || grep -Eiq 'MPI_ABORT|APPLICATION TERMINATED|BAD TERMINATION' "$err" 2>/dev/null; then FAILTYPE=MPI_ABORT; return; fi
  # 게이트 사유로 세분
  case "$GATE_REASON" in
    *maxele*) FAILTYPE=NO_MAXELE; return;;
    *RNDAY*)  FAILTYPE=DID_NOT_REACH_RNDAY; return;;
  esac
  FAILTYPE=UNKNOWN
}

# ── 소넷 프롬프트 작성 ──────────────────────────────────────────────────────
build_prompt(){
  local f15="$RUN_DIR/fort.15"
  local cur_dt cur_tau cur_dramp cur_rnday cur_w pc nwp f13names
  cur_dt="$(awk 'NR==22{print $1}' "$f15")"
  cur_tau="$(awk 'NR==21{print $1}' "$f15")"
  cur_dramp="$(awk 'NR==26{print $1}' "$f15")"
  cur_rnday="$(awk 'NR==25{print $1}' "$f15")"
  cur_w="$(awk 'NR==27{print $1, $2, $3}' "$f15")"
  case "$cur_dt" in -*) pc="ON(예측자-수정자)";; *) pc="OFF";; esac
  nwp="$(sed -n '14,15p' "$f15")"
  if [ "${INCLUDE_F13:-0}" = "1" ]; then
    f13names="$(grep -iE '_at_sea_floor|_in_continuity_equation' "$RUN_DIR/fort.13" 2>/dev/null | sort -u)"
  else
    f13names="(이번 실패유형에선 불필요 — 필요시 ./fort.13 직접 Read)"
  fi

  cat > "$CYC/claude_prompt.txt" <<PROMPT
당신은 실패한 ADCIRC v53 런의 입력파일 ./fort.15 하나만 손봐서 안정화하는 판정자(judge)다.
아래 증거로부터 원인을 스스로 판단하고, 허용범위 안에서 가장 작은 수정 하나만 적용하라.
원인을 미리 가정하지 말고 증거를 읽고 결정하라.

=== 하드 제약 (하나라도 위반하면 실패) ===
- ./fort.15 만 EDIT 한다. 그 안에서도 다음만 바꿀 수 있다:
   (a) 안정성 파라미터: DT(부호 중요 — 음수면 예측자-수정자 켜짐), DRAMP, TAU0, GWCE 시간가중 A00 B00 C00.
   (b) NWP 절점속성명 줄(L14/L15) — 단, "nodal attribute not found" 류 실패일 때
       fort.13에 실제로 존재하는 이름으로 맞추는 경우에만. fort.13은 수정 불가이니
       fort.15의 참조이름을 고친다. 속성 추가/삭제·NWP 개수 변경 금지.
- 물리/옵션(IM, NWS, NOLIBF/NOLIFA/NOLICA/NOLICAT, NWP 정수, NBFR/강제), RNDAY, 메시,
   그리고 fort.15 외 어떤 파일도 바꾸지 마라.
- 나머지 모든 줄은 바이트 단위로 보존(주석·열정렬 포함). 줄 추가/삭제 금지.
- 최소 변경(파라미터 1~2개 또는 이름 1개). 전부 갈아엎지 마라.

=== 측정된 실패 증거 (이번 런, sample_run 한정) ===
- 분류 시그니처     : ${FAILTYPE}
- adcprep 종료코드  : ${adcprep_rc:-NA}
- mpirun 종료코드   : ${mpi_rc:-NA}
- 마지막 TIME STEP  : ${LAST_TS}   (sim초 = LAST_TS * |DT|)
- ELMAX(있으면)     : ${ELMAX:-NA}
- log.dat(stdout) 꼬리 40줄:
$(tail -n 40 "$CYC/stdout.log" 2>/dev/null)
- stderr 꼬리 40줄(원래 mpi.sh가 버리던 스트림):
$(tail -n 40 "$CYC/stderr.log" 2>/dev/null)

=== 현재 fort.15 범위내 값(실측) ===
- DT=${cur_dt} (예측자-수정자 ${pc})  TAU0=${cur_tau}  DRAMP=${cur_dramp} 일 (RNDAY=${cur_rnday} 일, 읽기전용)
- A00 B00 C00 = ${cur_w}
- fort.15가 요구하는 NWP 절점속성명(L14/L15):
${nwp}
- fort.13에 실제 존재하는 속성명(불일치 점검용):
${f13names}

=== ★ 팀 진단 우선순위 (CHECK_PRIORITY.md) — 최우선 권위 가이드 ★ ===
아래는 우리 팀(JM)이 정리한 mpi.sh 진단 우선순위다. v53 매뉴얼과 충돌하면
"이 셋업에서 무엇을 택할지"는 이 팀 가이드를 우선한다. 특히:
  - P2: DT 는 반드시 > 0 (양수). 음수 DT(예측자-수정자)는 이 팀 기준에선 쓰지 않는다.
  - P6: CFL 안정성 C = sqrt(g·h_max)·DT/dx_min ≤ 4 (권고). 발산이면 DT를
        격자/수심 기준 CFL 충족 "양수" 값으로 줄여라(예: 100m 격자면 ≤ 2~5초).
  - P3: NWP 속성명은 fort.13 속성명과 정확히 일치(불일치면 fort.15 이름 정정).
  - P2: DRAMP 0.5~2.0 일 권고(<0.25일이면 초기충격 위험).
─────────── CHECK_PRIORITY.md 전문 ───────────
$(cat "$PRIORITY_DOC" 2>/dev/null || echo "(CHECK_PRIORITY.md 로드 실패)")
──────────────────────────────────────────────

=== ADCIRC v53 참조 (보조 — 위 팀 가이드와 충돌 시 팀 가이드 우선) ===
- fort.15 페이지        : ${MANUAL}
- 파라미터 정의 페이지  : ${MANUAL2}
- 보조 지침:
   * 표고 발산(ErrorElev / Elevation.gt / 매우 큰 표고): CFL 위반이 1순위. P6에 따라
     DT를 CFL 충족 "양수" 값으로 축소(부호 반전 금지 — P2). 부수적으로 GWCE 가중(TAU0/
     A00:B00:C00) 강화나 DRAMP(0.5~2.0일) 조정도 가능하나, 1차 레버는 DT 양수 축소다.
   * NaN/Infinity: 같은 CFL 계열의 더 빠른 발산. DT를 더 크게(양수로) 줄여라.
   * 램프 구간(sim < DRAMP*86400) 실패: DRAMP를 0.5~2.0일 범위로 조정(P2).
   * "nodal attribute ... not found": 수치문제 아님. fort.15 속성명을 fort.13에 있는
     이름으로 정정(P3). 수치값은 건드리지 마라.
   ./fort.13, ./fort.14(최소요소크기·최대수심→CFL 계산), ./machine, ./mpi.sh 를 Read 해도 된다.

=== 출력 ===
1) ./fort.15 를 최소수정(형식 보존)으로 Edit 하라.
2) 그 다음 한 단락으로: 바꾼 항목(old -> new), 근거 이유, 의지한 CHECK_PRIORITY 항목(P#)과
   v53 파라미터를 적어라. 파일 전체를 다시 출력하지 마라.
PROMPT
}

# ── fort.15 외 변경 감지·복원 (해시 가드) ──────────────────────────────────
PROTECT="fort.13 machine mpi.sh adcprep padcirc"  # 소넷이 잘못 손댈 위험 있는 핵심 참조
snapshot_refs(){
  : > "$CYC/pre_refs.sha"
  local f
  for f in $PROTECT; do
    [ -f "$RUN_DIR/$f" ] && sha256sum "$RUN_DIR/$f" >> "$CYC/pre_refs.sha"
  done
  # fort.14(45MB)는 백업 대신 해시만; 변하면 하드중단
  [ -f "$RUN_DIR/fort.14" ] && sha256sum "$RUN_DIR/fort.14" > "$CYC/pre_fort14.sha"
  # 복원용 소형 참조 백업
  mkdir -p "$CYC/refs_backup"
  for f in fort.13 machine mpi.sh; do
    [ -f "$RUN_DIR/$f" ] && cp -p "$RUN_DIR/$f" "$CYC/refs_backup/$f"
  done
}
guard_refs(){
  local bad=0
  # fort.14 무결성 (복원 불가 → 변하면 하드중단)
  if [ -f "$CYC/pre_fort14.sha" ] && ! sha256sum -c --quiet "$CYC/pre_fort14.sha" 2>/dev/null; then
    die "소넷이 fort.14(메시)를 변경함 — 복원 불가, 즉시 중단. (수동 점검 필요)"
  fi
  # 소형 참조 변경 복원
  while read -r want path; do
    local got; got="$(sha256sum "$path" 2>/dev/null | awk '{print $1}')"
    if [ "$got" != "$want" ]; then
      local base; base="$(basename "$path")"
      if [ -f "$CYC/refs_backup/$base" ]; then
        cp -p "$CYC/refs_backup/$base" "$path" && say "${CY}[GUARD]${C0} $base 가 변경되어 백업에서 복원함"
        bad=1
      else
        die "참조파일 $base 가 변경됐으나 백업 없음 — 중단"
      fi
    fi
  done < "$CYC/pre_refs.sha"
  return $bad
}

# ── fort.15 변경 범위 검사 (허용줄만 다르고 RNDAY 불변) ─────────────────────
check_scope(){
  local pre="$CYC/refs/fort.15.precycle" now="$RUN_DIR/fort.15"
  # 줄 수 동일?
  if [ "$(wc -l < "$pre")" != "$(wc -l < "$now")" ]; then
    say "${CR}[SCOPE]${C0} 줄 수가 바뀜(줄 추가/삭제 금지 위반)"; return 1
  fi
  # 허용줄을 마스킹한 뒤 나머지가 동일해야 함
  local masked_pre masked_now
  masked_pre="$(awk -v a="$ALLOWED_LINES" 'BEGIN{n=split(a,A," ");for(i=1;i<=n;i++)M[A[i]]=1}{print (NR in M)?"__MASK__":$0}' "$pre")"
  masked_now="$(awk -v a="$ALLOWED_LINES" 'BEGIN{n=split(a,A," ");for(i=1;i<=n;i++)M[A[i]]=1}{print (NR in M)?"__MASK__":$0}' "$now")"
  if [ "$masked_pre" != "$masked_now" ]; then
    say "${CR}[SCOPE]${C0} 허용범위(L${ALLOWED_LINES// /,}) 밖의 줄이 변경됨"
    diff <(printf '%s' "$masked_pre") <(printf '%s' "$masked_now") | head -20
    return 1
  fi
  # RNDAY(L25) 불변 재확인
  if [ "$(sed -n "${RNDAY_LINE}p" "$pre")" != "$(sed -n "${RNDAY_LINE}p" "$now")" ]; then
    say "${CR}[SCOPE]${C0} RNDAY(L${RNDAY_LINE}) 변경됨 — 금지"; return 1
  fi
  return 0
}

# ── 한 사이클 수행 ──────────────────────────────────────────────────────────
do_cycle(){
  ITER=$((ITER+1))
  CYC="$LOGROOT/$SESSION/cycle_$ITER"
  mkdir -p "$CYC/refs"
  say "${CB}═══ CYCLE $ITER  (session $SESSION) ═══${C0}"

  if [ "$ITER" -gt "$MAX_ITER" ]; then
    say "${CR}[STOP]${C0} 최대 사이클($MAX_ITER) 초과 — 중단·보고. 필요시 MAX_ITER 상향."
    RESOLVED="maxiter"; save_state; exit 2
  fi

  ensure_mpi
  probe_nodes

  # ── 실행 (stdout/stderr 분리 포착) ──
  say "[run] adcprep + mpirun (np=$NP, timeout=${MAX_WALL}s) ..."
  ( cd "$RUN_DIR" && ./adcprep --partmesh --np "$NP" && ./adcprep --prepall --np "$NP" ) \
      > "$CYC/adcprep.log" 2>&1
  adcprep_rc=$?
  ( cd "$RUN_DIR" && date > run_time.dat
    timeout "$MAX_WALL" mpirun -n "$NP" -machinefile machine ./padcirc \
        > "$CYC/stdout.log" 2> "$CYC/stderr.log"
    echo $? > "$CYC/mpi_rc"
    cp -f "$CYC/stdout.log" log.dat
    date >> run_time.dat )
  mpi_rc="$(cat "$CYC/mpi_rc" 2>/dev/null || echo 1)"
  [ "$mpi_rc" = "124" ] && say "${CY}[WARN]${C0} mpirun 타임아웃(${MAX_WALL}s) 도달"

  # ── 성공게이트 ──
  if success_gate; then
    hr; say "${CG}${CB}✅ 성공: 4중 게이트 통과 (완주+무발산+maxele.63+Status=0)${C0}"
    say "  로그: $CYC/  |  산출물: $RUN_DIR/maxele.63"
    JOURNAL "## Cycle $ITER — ✅ 성공 ($(date '+%Y-%m-%d %H:%M:%S'))"
    JOURNAL ""
    JOURNAL "- 4중 게이트 통과: RNDAY 완주 + 무발산(stdout/stderr) + maxele.63 생성·유한 + MPI Status=0."
    JOURNAL "- 산출물: \`$RUN_DIR/maxele.63\`"
    JOURNAL ""
    JOURNAL "---"
    RESOLVED="success"; LAST_FAILTYPE=""; save_state; hr
    say "  📒 누적 수정저널: $LOGROOT/$SESSION/FIX_JOURNAL.md"
    exit 0
  fi

  # ── 실패: 분류·발췌 ──
  classify
  LAST_FAILTYPE="$FAILTYPE"
  {
    echo "FAILTYPE=$FAILTYPE"; echo "GATE_REASON=$GATE_REASON"
    echo "adcprep_rc=$adcprep_rc  mpi_rc=$mpi_rc  last_ts=$LAST_TS  ELMAX=${ELMAX:-NA}  NODE_WARN=$NODE_WARN"
  } > "$CYC/diagnosis.txt"
  hr
  say "${CR}✗ 실패${C0}  FAILTYPE=${CB}$FAILTYPE${C0}  (gate: ${GATE_REASON:-n/a})"
  say "  adcprep_rc=$adcprep_rc  mpi_rc=$mpi_rc  last_ts=$LAST_TS  ELMAX=${ELMAX:-NA}"

  # ── 환경/구성 오류 → 소넷 호출 안 함 ──
  if echo " $ENV_FAILTYPES " | grep -q " $FAILTYPE "; then
    say "${CY}[환경오류]${C0} $FAILTYPE 는 fort.15 안정성 문제가 아님 → 소넷 미호출."
    case "$FAILTYPE" in
      ADCPREP_FAIL) say "  adcprep 단계 실패. $CYC/adcprep.log 확인 (np/메시/분할/PE* 잔재).";;
      MPI_ABORT)    say "  mpirun 비정상 종료. 노드 상태(NODE_WARN=$NODE_WARN)/setvars/hostfile 확인. $CYC/stderr.log";;
      RUN_TIMEOUT)  say "  mpirun 이 ${MAX_WALL}s 타임아웃에 걸림(발산 아님일 수 있음). 안정 런이 더 길면 MAX_WALL 상향 후 재실행: MAX_WALL=3600 $0 run";;
    esac
    JOURNAL "## Cycle $ITER — ⚠ 환경/구성 오류: $FAILTYPE ($(date '+%Y-%m-%d %H:%M:%S'))"
    JOURNAL ""
    JOURNAL "- 게이트: ${GATE_REASON:-n/a}  /  adcprep_rc=$adcprep_rc mpi_rc=$mpi_rc"
    JOURNAL "- fort.15 안정성 문제가 아니라 판단 → 소넷 미호출. 환경(노드/setvars/분할) 조치 필요."
    JOURNAL ""
    JOURNAL "---"
    RESOLVED="env_error"; save_state
    say "원인 해소 후 다시 ${CB}run${C0} 하세요."; exit 3
  fi

  # ── 소넷 수정 (샌드박스) ──
  cp -p "$RUN_DIR/fort.15" "$CYC/refs/fort.15.precycle"
  local stamp backup; stamp="$(date +%Y%m%d_%H%M%S)"
  backup="$RUN_DIR/fort.15.bak.${SESSION}.cycle${ITER}_${stamp}"
  cp -p "$RUN_DIR/fort.15" "$backup"
  LAST_BACKUP="$backup"

  snapshot_refs
  build_prompt

  say "[claude] 소넷($MODEL) 호출 — fort.15만 쓰기(샌드박스)…"
  # 프롬프트는 stdin 으로 전달한다 — --disallowedTools 등 가변인자 플래그가
  # 위치인자(프롬프트)를 삼키는 문제를 피하기 위함.
  ( cd "$RUN_DIR" && "$CLAUDE_BIN" -p --model "$MODEL" \
        --permission-mode acceptEdits \
        --allowedTools Read Edit WebFetch Grep Glob \
        --disallowedTools Bash Write \
        --add-dir "$RUN_DIR" < "$CYC/claude_prompt.txt" ) > "$CYC/claude_out.txt" 2>&1
  local crc=$?
  say "  (claude rc=$crc, 근거: $CYC/claude_out.txt)"

  # ── 가드 ──
  guard_refs || true
  if ! check_scope; then
    say "${CR}[가드]${C0} 범위 위반 → fort.15 를 백업에서 복원하고 중단."
    cp -p "$backup" "$RUN_DIR/fort.15"
    JOURNAL "## Cycle $ITER — ⛔ 가드: 범위 위반 ($(date '+%Y-%m-%d %H:%M:%S'))"
    JOURNAL "- 소넷이 허용범위(L${ALLOWED_LINES// /,}) 밖을 변경 → 백업에서 복원하고 중단. (FAILTYPE=$FAILTYPE)"
    JOURNAL ""; JOURNAL "---"
    RESOLVED="scope_violation"; save_state; exit 4
  fi
  if cmp -s "$CYC/refs/fort.15.precycle" "$RUN_DIR/fort.15"; then
    say "${CY}[no-op]${C0} 소넷이 fort.15 를 바꾸지 않음. 근거 로그 확인 후 재시도하세요."
    JOURNAL "## Cycle $ITER — ◻ 무변경(no-op) ($(date '+%Y-%m-%d %H:%M:%S'))"
    JOURNAL "- FAILTYPE=$FAILTYPE 인데 소넷이 fort.15 를 바꾸지 않음. 근거: \`$CYC/claude_out.txt\`"
    JOURNAL ""; JOURNAL "---"
    RESOLVED="noop"; save_state; exit 5
  fi

  # ── diff 제시 + 일시정지 ──
  diff -u "$CYC/refs/fort.15.precycle" "$RUN_DIR/fort.15" > "$CYC/fort15.diff"
  RESOLVED="awaiting_approval"; save_state

  # ── 누적 수정저널 기록 (왜 오류 / 무엇을 / 왜) ──
  local chg keyl
  chg="$(grep -E '^[-+]' "$CYC/fort15.diff" | grep -vE '^(---|\+\+\+)')"
  keyl="$( { tail -n 5 "$CYC/stderr.log"; tail -n 3 "$CYC/stdout.log"; } 2>/dev/null | grep -vE '^\s*$' | tail -n 6)"
  JOURNAL "## Cycle $ITER — $(date '+%Y-%m-%d %H:%M:%S')"
  JOURNAL ""
  JOURNAL "### ① 왜 오류 (증상)"
  JOURNAL "- 분류: **$FAILTYPE**  /  게이트: ${GATE_REASON:-n/a}"
  JOURNAL "- adcprep_rc=$adcprep_rc · mpi_rc=$mpi_rc · last_ts=$LAST_TS · ELMAX=${ELMAX:-NA}"
  JOURNAL "- 핵심 로그:"
  JOURNAL '```'
  JOURNAL "${keyl:-(로그 없음)}"
  JOURNAL '```'
  JOURNAL ""
  JOURNAL "### ② 무엇을 고침 (fort.15 변경)"
  JOURNAL '```diff'
  JOURNAL "$chg"
  JOURNAL '```'
  JOURNAL "- 백업: \`$backup\`"
  JOURNAL ""
  JOURNAL "### ③ 왜 그렇게 고침 (소넷 근거)"
  JOURNAL "$(cat "$CYC/claude_out.txt")"
  JOURNAL ""
  JOURNAL "_상태: 승인대기 — approve 시 다음 사이클에서 이 수정을 검증_"
  JOURNAL ""
  JOURNAL "---"
  hr
  say "${CB}제안된 fort.15 변경 (cycle $ITER):${C0}"
  sed -n '1,60p' "$CYC/fort15.diff"
  hr
  say "소넷 근거:"; sed -n '1,40p' "$CYC/claude_out.txt"
  hr
  say "백업: $backup"
  say "  📒 누적 수정저널(왜 오류·무엇을·왜): $LOGROOT/$SESSION/FIX_JOURNAL.md"
  say "${CB}승인하면 다음 사이클 재실행:${C0}  $0 approve"
  say "${CB}되돌리고 중단:${C0}              $0 revert"
  exit 0   # ★ 회당 수동승인 경계: 스스로 재실행하지 않음
}

# ── 메인 ────────────────────────────────────────────────────────────────────
load_state
case "$MODE" in
  run)
    if [ -n "$SESSION" ] && [ "$RESOLVED" = "awaiting_approval" ]; then
      die "미승인 세션($SESSION, cycle $ITER) 존재 → approve 또는 revert 먼저. 새로 시작하려면 status 확인."
    fi
    SESSION="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOGROOT/$SESSION"
    echo "$SESSION" > "$CUR_PTR"
    STATE="$LOGROOT/$SESSION/state.env"
    ITER=0; LAST_FAILTYPE=""; LAST_BACKUP=""; RESOLVED=""
    say "${CB}새 세션 시작: $SESSION${C0}  (RUN_DIR=$RUN_DIR)"
    { echo "# ADCIRC 자가치유 수정저널 — 세션 $SESSION"
      echo ""
      echo "- 대상: \`$RUN_DIR\`"
      echo "- 각 사이클을 **왜 오류 났는지 / 무엇을 고쳤는지 / 왜 고쳤는지** 순으로 누적한다."
      echo ""
      echo "---"; } > "$LOGROOT/$SESSION/FIX_JOURNAL.md"
    do_cycle
    ;;
  approve)
    [ -n "$SESSION" ] || die "활성 세션 없음 — 먼저 run."
    [ "$RESOLVED" = "awaiting_approval" ] || say "${CY}[주의]${C0} 직전 상태가 awaiting_approval 아님(=$RESOLVED). 그래도 진행."
    say "${CG}[승인]${C0} cycle $ITER 의 fort.15 수정 채택 → 다음 사이클 수행."
    do_cycle
    ;;
  revert)
    [ -n "$SESSION" ] || die "활성 세션 없음."
    if [ -n "$LAST_BACKUP" ] && [ -f "$LAST_BACKUP" ]; then
      cp -p "$LAST_BACKUP" "$RUN_DIR/fort.15"
      say "${CG}[복원]${C0} fort.15 ← $LAST_BACKUP"
    else
      say "${CY}[주의]${C0} 복원할 백업 없음(LAST_BACKUP=$LAST_BACKUP)."
    fi
    JOURNAL "## (revert) cycle $ITER 수정 되돌림 ($(date '+%Y-%m-%d %H:%M:%S'))"
    JOURNAL "- 사용자가 직전 fort.15 수정을 반려 → 백업 복원, 세션 중단."
    JOURNAL ""; JOURNAL "---"
    RESOLVED="reverted"; save_state
    say "세션 $SESSION 중단. 새로 하려면 run."
    ;;
  status)
    if [ -z "$SESSION" ]; then say "활성 세션 없음. 시작: $0 run"; exit 0; fi
    say "세션      : $SESSION"
    say "사이클    : $ITER / $MAX_ITER"
    say "상태      : ${RESOLVED:-진행중}"
    say "마지막실패: ${LAST_FAILTYPE:-none}"
    say "마지막백업: ${LAST_BACKUP:-none}"
    say "로그      : $LOGROOT/$SESSION/"
    ;;
  *)
    die "알 수 없는 모드: $MODE  (run | approve | revert | status)"
    ;;
esac
