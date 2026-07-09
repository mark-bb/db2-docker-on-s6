#!/bin/bash
#
set -x

# Install the software
S6_DISTRIB_DIR="${DISTRIB_DIR?}/s6-overlay"
SYSLOG_USERS="syslog:32760 sysllog:32761"

for f in $(ls "${S6_DISTRIB_DIR?}"/*.xz); do
  tar -C / -Jxpf "${f?}"
done

# Copy s6 configs & scripts
cp -a /setup/s6-rc.d /etc/s6-overlay/
cp -a /setup/cont-finish.d /etc/

f=init-runner
cp "${S6_DISTRIB_DIR?}/${f?}" /
chmod u+s "/${f?}"

for ent in ${SYSLOG_USERS?}; do 
  id=${ent#*:}
  u=$(getent passwd ${id?} 2>/dev/null) && userdel -r ${u%%:*}
  g=$(getent group  ${id?} 2>/dev/null) && groupdel   ${g%%:*}
  useradd -s /usr/sbin/nologin -u ${id?} ${ent%:*}
done
