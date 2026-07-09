#!/bin/bash
#
# Function: setup a container
#

fix_files() {
  # fixing files...
  MYHOST="$(cat /proc/sys/kernel/hostname)"
  "${DB2PATH?}/instance/db2iset" -g DB2SYSTEM=${MYHOST?}
  echo "0 ${MYHOST?} 0" > "${DB2_HOME?}/db2nodes.cfg"

  if ! grep -E "[^0-9]${DB2PORT?}/tcp" /etc/services &>/dev/null; then
	cat <<-EOF | tee -a /etc/services
	db2c_${DB2INSTANCE?}      ${DB2PORT?}/tcp
	DB2_${DB2INSTANCE?}       60000/tcp
	DB2_${DB2INSTANCE?}_END   60000/tcp
	EOF
  fi
}

fix_problems() {
  # fixing various places...
  fix_files

  f="${DB2_HOME?}/adm/fencedid"
  [ "$(ls -l "${f?}" | awk '{print $4}')" != "${DB2IGROUP?}" ] && chgrp ${DB2IGROUP?} "${f?}"

  [ -f "${DB2_HOME?}/.ftok" ] && su - ${DB2INSTANCE?} -c 'rm -f sqllib/.ftok ; sqllib/bin/db2ftok'
  
  # Sometimes the db2 upgrade cleans them out due to unknown reason
  kv_str="SVCENAME:db2c_${DB2INSTANCE?} SYSADM_GROUP:${DB2IGROUP?}"
  IFS=' ' read -r -a kv  <<< "${kv_str?}"
  for x in "${!kv[@]}"; do
    parm=${kv[x]%:*}
    val_need=${kv[x]#*:}
    val_curr="$(su - ${DB2INSTANCE?} -c "db2 get dbm cfg | grep -F '(${parm?})'" | awk -F'= ' '{print $2}')"
    [ "X${val_curr?}" = "X" ] && su - ${DB2INSTANCE?} -c "db2 update dbm cfg using ${parm?} ${val_need?}"
  done
}

update_cfg() {
  su - ${DB2INSTANCE?} -c "db2 \"update dbm cfg using DFTDBPATH '${DATADIR?}'\""
}

update_upgrade() {
  # If really needed only
  [ "X${vrmf_users?}" = "X" ] && return 0

  for db in $(list_local_dbs); do
    # Check from the db cfg if the upgrade is needed
    status=$(su - ${DB2INSTANCE?} -c "db2 get db cfg for ${db?} | awk -F'= ' '/release level/ {print $2}' | sort -u | wc -l")
    if [ ${status?} -ne 1 ]; then
      # Upgrade
      su - ${DB2INSTANCE?} -c "db2 upgrade database ${db?}"
    elif [ "${vrmf_distr?}" != "${vrmf_users?}" ]; then
      # Update
      DB2UPDV="$(find "${DB2PATH?}/bin" -name 'db2updv*')"
      su - ${DB2INSTANCE?} -c "set -x;
          ${DB2UPDV?} -d ${db?} ;
          db2 connect to ${db?} ;
          db2 BIND '${DB2_HOME?}/bnd/db2schema.bnd' BLOCKING ALL GRANT PUBLIC SQLERROR CONTINUE ;
          db2 BIND '${DB2_HOME?}/bnd/@db2ubind.lst' BLOCKING ALL GRANT PUBLIC ACTION ADD ;
          db2 BIND '${DB2_HOME?}/bnd/@db2cli.lst' BLOCKING ALL GRANT PUBLIC ACTION ADD ;
          db2 terminate ; "
    fi
  done
}

list_local_dbs() {
  su - ${DB2INSTANCE?} -c "db2 list db directory | awk -v RS='' '/= Indirect/' | awk -F'= ' '/Database alias/{print \$2}'"
}

activate_local_dbs() {
  # Activate all local databases
  for db in $(list_local_dbs); do
    su - ${DB2INSTANCE?} -c "db2 activate db ${db?}"
  done
}

exec_scripts() {
  local d="${1?"Some directory must be provided"}"
  [ -d "${d?}" ] || return 1
  for s in $(ls "${d?}/"); do fs="${d?}/${s?}"; [ -f "${fs?}" -a -x "${fs?}" ] && ${fs?}; done
}

on_stop() {
  su - ${DB2INSTANCE?} -c "db2stop force"
  for pid in "${!pids[@]}"; do kill -TERM ${pid?}; done
}

watchdog() {
  # Kills the main process to inform the supervisor
  while :; do
    sleep 10
    su - ${DB2INSTANCE?} -c "db2gcf -s" &>/dev/null
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
. "${ENV_FILES_DIR?}/db2-rt.sh"

PID=$$
DB2LS_OUT="$(db2ls -c | tail -1)"
DB2PATH="$(printf "${DB2LS_OUT?}" | cut -d':' -f1)"

vrmf_distr="$(printf "${DB2LS_OUT?}" | cut -d':' -f2)"
[ -d "${DB2_HOME?}" ] && vrmf_users=$(source "${DB2_HOME?}/.instuse" && printf "${V?}.${R?}.${M?}.${F?}") || vrmf_users=""
vr_distr=$(printf "${vrmf_distr?}" | awk -v FS='.' '{print $1"."$2'})
vr_users=$(printf "${vrmf_users?}" | awk -v FS='.' '{print $1"."$2'})

# Add the instance record except a new installation or upgrade
[ "X${vrmf_users?}" = "X" -o "${vr_distr?}" != "${vr_users?}" ] || \
  { "${DB2PATH?}/bin/db2greg" -getinstrec instancename=${DB2INSTANCE?} | grep InstanceName &>/dev/null \
    || "${DB2PATH?}/bin/db2greg" -addinstrec service=DB2,instancename=${DB2INSTANCE?}; }

if [ "${vrmf_distr?}" != "${vrmf_users?}" ]; then
  fs_protected_regular=$(cat /proc/sys/fs/protected_regular)
  [ ${fs_protected_regular?} -ne 0 ] && { printf 0 > /proc/sys/fs/protected_regular; }
  [ -d "${DB2_HOME?}" ] && fix_files

  # They have made -nosharedgroup or -sharedgroup option necessary in 12.1.5.0
  options=""
  vrmf_distr_num=$(printf "${vrmf_distr?}" | awk -F'.' '{print $4 + $3*100 + $2*10000 + $1*1000000}')
  [ ${vrmf_distr_num?} -ge 12010500 ] && options+=" -nosharedgroup"

  "${DB2PATH?}/instance/db2icrt" -update-instance-if-exists -p ${DB2PORT?} -u ${DB2FUSER?} ${options?} ${DB2INSTANCE?}
  [ ${fs_protected_regular?} -ne 0 ] && { printf ${fs_protected_regular?} > /proc/sys/fs/protected_regular; }
fi

if [ "X${vrmf_users?}" = "X" ]; then
  # New installation
  update_cfg
fi

fix_problems

if [ "X${TO_START_INSTANCE}" != "Xfalse" ]; then
  exec_scripts "${PRE_START_SCRIPT_DIR?}"
  su - ${DB2INSTANCE?} -c "db2start"
  set +x; watchdog & pids[$!]=""; set -x
  exec_scripts "${POST_START_SCRIPT_DIR?}"
  update_upgrade
  activate_local_dbs
fi

trap on_stop SIGTERM SIGINT

su - ${DB2INSTANCE?} -c "db2diag -readfile -f" &
pids[$!]=""
wait
