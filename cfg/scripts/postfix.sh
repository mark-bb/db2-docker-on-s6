#!/usr/bin/env bash
#

on_signal() {
  set -x
  local sig=$1
  /usr/sbin/postfix ${sig?}
  [ "X${sig?}" = "Xstop" ] && for pid in "${!pids[@]}"; do kill -TERM ${pid?}; done 
}

set -x
declare -A pids
# DIR="$(cd "$(dirname "$0")" && pwd -P)"
# . "${DIR?}/utils.sh"
# . "${ENV_FILES_DIR?}/postfix.sh"

# Start Postfix
/usr/sbin/postfix start-fg &

trap "on_signal stop" SIGTERM SIGINT
trap "on_signal reload" SIGHUP


set +x
while :; do sleep 86400; done &
pids[$!]=""
wait
