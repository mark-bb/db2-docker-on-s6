#!/bin/bash
#
# FUNCTION: adds / changes additional users and groups
#

set -x
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "${DIR?}/utils.sh"

# ADDGROUPS="db2grp1:1001 db2grp2:1002"
# ADDUSERS="root:0:passw0rd db2user1:1001:passw0rd:db2grp1,db2grp2 db2user2:1002:passw0rd:db2grp2 db2user3:1003:passw0rd"

if [ "X${ADDGROUPS}" != "X" ]; then
  IFS=' ' read -r -a addgroups <<< "${ADDGROUPS}"
  for x in "${!addgroups[@]}"; do
    unset addgroup
    IFS=':' read -r -a addgroup <<< "${addgroups[x]}"
    getent group ${addgroup[0]} &>/dev/null || groupadd -g ${addgroup[1]} ${addgroup[0]}
  done
fi

if [ "X${ADDUSERS}" != "X" ]; then
  [ -d "${BASEUSERDIR?}" ] || mkdir -p "${BASEUSERDIR?}"
  IFS=' ' read -r -a addusers  <<< "${ADDUSERS}"
  for x in "${!addusers[@]}"; do
    unset adduser
    IFS=':' read -r -a adduser <<< "${addusers[x]}"
    [ "X$(printf "${adduser[0]}" | tr '[[:upper:]]' '[[:lower:]]')" = "Xroot" ] && continue
    printf "${adduser[3]}" | tr '[[:upper:]]' '[[:lower:]]' | grep "root" &>/dev/null && continue
    [ "X${adduser[3]}" != "X" ] && pgrp="-g $(printf "${adduser[3]}" | cut -d, -f1)" || pgrp=""
    getent passwd ${adduser[0]} &>/dev/null || useradd -m -b "${BASEUSERDIR?}" -s /bin/bash -u ${adduser[1]} ${pgrp?} ${adduser[0]}
    [ "X${adduser[3]}" != "X" ] && usermod -G ${adduser[3]} ${adduser[0]}
    # echo "${adduser[0]}:${adduser[2]}" | chpasswd
    usermod -p "${adduser[2]}" "${adduser[0]}"
  done
fi
