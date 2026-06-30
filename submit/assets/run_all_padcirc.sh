#!/bin/bash
# ────────────────────────────────────────────────────────────
# 가상태풍 전체 파이프라인 일괄 수행 (padcirc, 클러스터 node4/6/11=150코어)
#   01 pre(바람장+fort.15+hotstart모델) → 02 본모델 → 03 onlytide → 04 post
# oneAPI MPI 환경을 먼저 로드한 뒤 csh 스크립트들을 순차 실행.
# ────────────────────────────────────────────────────────────
set -e
source /appl/opt/oneapi/setvars.sh >/dev/null 2>&1
export I_MPI_HYDRA_BOOTSTRAP=ssh

cd "$(dirname "$0")"
echo "########## START $(date) ##########"

echo "########## [01] PRE (wind + fort.15 + hotstart model) $(date) ##########"
csh 01_runp_pre.csh

echo "########## [02] MAIN MODEL (padcirc, np=150) $(date) ##########"
csh 02_runp_model_padcirc.csh 150

echo "########## [03] ONLYTIDE (surge 분리) $(date) ##########"
csh 03_runp_onlytide.csh

echo "########## [04] POST (가시화) $(date) ##########"
csh 04_runp_post.csh

echo "########## DONE $(date) ##########"
