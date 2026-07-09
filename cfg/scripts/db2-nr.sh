#!/bin/bash
#
# FUNCTION: Starts up the container
#

fix_files() {
  # fixing files
  MYHOST="$(cat /proc/sys/kernel/hostname)"
  chmod u+w "${DB2_HOME?}/db2nodes.cfg"
  echo "0 ${MYHOST?} 0" > "${DB2_HOME?}/db2nodes.cfg"
}

fix_problems() {
  # fixing various places...
  fix_files
  db2set DB2SYSTEM=${MYHOST?}
  [ -f "${DB2_HOME?}/.ftok" ] && { rm -f ${DB2_HOME?}/.ftok; ${DB2_HOME?}/bin/db2ftok; }
}

update_cfg() {
  db2 "update dbm cfg using DFTDBPATH ${DATADIR?}"
}

update_upgrade() {
  # If really needed only
  [ "X${vrmf_users?}" = "X" -o "X${vrmf_distr?}" = "X" ] && return 0
  for db in $(list_local_dbs); do
    # Check from the db cfg if the upgrade is needed
    status=$(db2 "get db cfg for ${db?}" | awk -F'= ' '/release level/ {print $2}' | sort -u | wc -l)
    if [ ${status?} -ne 1 ]; then
      # Upgrade
      db2 upgrade database ${db?}
    elif  [ "${vrmf_distr?}" != "${vrmf_users?}" ]; then
      # Update
      DB2UPDV="$(find "${DB2_HOME?}/bin" -name 'db2updv*')"
      "${DB2UPDV?}" -d ${db?}
      db2 connect to ${db?}
      db2 "BIND '${DB2_HOME?}/bnd/db2schema.bnd' BLOCKING ALL GRANT PUBLIC SQLERROR CONTINUE"
      db2 "BIND '${DB2_HOME?}/bnd/@db2ubind.lst' BLOCKING ALL GRANT PUBLIC ACTION ADD"
      db2 "BIND '${DB2_HOME?}/bnd/@db2cli.lst' BLOCKING ALL GRANT PUBLIC ACTION ADD"
      db2 terminate
    fi
  done
}

exec_scripts() {
  local d="${1?"Some directory must be provided"}"
  [ -d "${d?}" ] || return 1
  for s in $(ls "${d?}/"); do fs="${d?}/${s?}"; [ -f "${fs?}" -a -x "${fs?}" ] && ${fs?}; done
}

activate_local_dbs() {
  for db in $(list_local_dbs); do
    db2 activate db ${db?}
  done
}

on_stop() {
  db2stop force
  for pid in "${!pids[@]}"; do kill -TERM ${pid?}; done
}

watchdog() {
  # Kills the main process to inform the supervisor
  while :; do
    sleep 10
    db2gcf -s &>/dev/null
    status=$?
    if [ ${status?} -ne 0 ]; then
      kill -TERM ${PID?}
      break
    fi
  done
}


########
# MAIN
########

set -x
declare -A pids
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "${DIR?}/utils.sh"
. "${ENV_FILES_DIR?}/db2.sh"
. "${ENV_FILES_DIR?}/db2-nr.sh"

PID=$$
INSTDIR_DB2="$(dirname "$(find "${INSTDIR?}" -maxdepth 2 -type f -name db2setup)")"
vrmf_distr="$(grep '^vrmf' "${INSTDIR_DB2?}/db2/spec" | cut -d'=' -f2)"
[ -d "${DB2_HOME?}" ] && vrmf_users=$(source "${DB2_HOME?}/.instuse" && printf "${V?}.${R?}.${M?}.${F?}") || vrmf_users=""
vr_distr=$(printf "${vrmf_distr?}" | awk -v FS='.' '{print $1"."$2'})
vr_users=$(printf "${vrmf_users?}" | awk -v FS='.' '{print $1"."$2'})

if [ "X${vrmf_distr?}" != "X" ]; then
  [ -d "${DB2_HOME?}" ] && fix_files
  if [ "X${vrmf_users?}" == "X" -o "X${vr_distr?}" != "X${vr_users?}" ]; then
    echo "Major upgrade or Install New"
    "${INSTDIR_DB2?}/db2setup" -r ${RSPF?} -f sysreq
  elif [ "X${vrmf_distr?}" != "X${vrmf_users?}" ]; then
    echo "FixPack update"
    "${INSTDIR_DB2?}/installFixPack" -f db2lib -f sysreq -b "${DB2_HOME}" -y
  fi
fi

set +x
. "${DB2_HOME?}/db2profile"
set -x

fix_problems
rfetmpf="/tmp/db2rfe.cfg"
sed \
  -e "s/{{ DB2INSTANCE }}/${DB2INSTANCE?}/g" \
  -e "s/{{ DB2PORT }}/${DB2PORT?}/g" \
  "${RFEF?}" | tee "${rfetmpf?}"
sudo "${DB2_HOME}/instance/db2rfe" -f "${rfetmpf?}"
rm -f "${rfetmpf?}"
fix_problems

if [ "X${vrmf_users?}" == "X" ]; then
  # New installation
  update_cfg
fi

if [ "X${TO_START_INSTANCE}" != "Xfalse" ]; then
  exec_scripts "${PRE_START_SCRIPT_DIR?}"
  db2start
  set +x; watchdog & pids[$!]=""; set -x
  exec_scripts "${POST_START_SCRIPT_DIR?}"
  update_upgrade
  activate_local_dbs
fi

trap on_stop SIGTERM SIGINT

db2diag -readfile -f &
pids[$!]=""
wait
