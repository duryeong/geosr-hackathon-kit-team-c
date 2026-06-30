#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# 전처리기 바이너리의 NOTICE_BACKUP 하드코딩 경로 패치 (재현용)
#
# 배경:
#   mk_pre_fort15_22_26_MUN_v2.2.exe 에는 통보문 백업 경로
#   /home/storm/GEOSR/2022_v53_geosr/NOTICE_BACKUP/ (47 byte) 가 하드코딩돼 있다.
#   - 이 경로는 storm 유저 전용(700)이라 다른 계정은 접근/심볼릭 불가
#   - 소스(.F90) 재컴파일도 불가: mjdymd/TimeConv 서브루틴 소스 부재,
#     ifort 전용 무너비 포맷 '(I)' 16곳
#
# 해결:
#   바이너리 내 경로 문자열을 '같은 길이(47 byte)' 의 해커톤 폴더 경로로 치환.
#   길이가 동일하므로 ELF 오프셋이 깨지지 않아 안전하다.
#   /data1/syjeong/2026/Inundation/02_Hackathon/NB/  (정확히 47 byte)
#
# 사용:
#   bash patch_notice_backup_path.sh <대상exe경로>
#   예) bash patch_notice_backup_path.sh \
#         "/data1/.../source_GEO_Edit_2025(0927)/Wind/mk_pre_fort15_22_26_MUN_v2.2.exe"
# ─────────────────────────────────────────────────────────────────────
set -e

EXE="${1:?사용법: bash patch_notice_backup_path.sh <대상exe>}"

OLD='/home/storm/GEOSR/2022_v53_geosr/NOTICE_BACKUP/'
NEW='/data1/syjeong/2026/Inundation/02_Hackathon/NB/'

# 길이 동일성 검증 (다르면 중단 — 오프셋 손상 방지)
if [ "${#OLD}" -ne "${#NEW}" ]; then
  echo "ERROR: 경로 길이 불일치 (OLD=${#OLD}, NEW=${#NEW}) — 패치 중단" >&2
  exit 1
fi

# 원본 백업 (없을 때만)
[ -f "${EXE}.orig" ] || cp "$EXE" "${EXE}.orig"

python - "$EXE" "$OLD" "$NEW" <<'PY'
import sys
exe, old, new = sys.argv[1], sys.argv[2].encode(), sys.argv[3].encode()
assert len(old) == len(new), "length mismatch"
d = open(exe, 'rb').read()
n = d.count(old)
open(exe, 'wb').write(d.replace(old, new))
print("patched occurrences:", n)
PY

chmod 755 "$EXE"
echo "패치 완료: $EXE"
echo "확인:"; strings "$EXE" | grep -E "NOTICE_BACKUP|02_Hackathon/NB" || true
