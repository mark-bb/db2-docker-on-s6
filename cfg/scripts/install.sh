#!/bin/bash
#
# FUNCTION: install the software
#

set -x
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "${DIR?}/utils.sh"

# Processing secrets if any
SECRET_DIR="/run/secrets"
[ -d "${SECRET_DIR?}" ] && . <(find "${SECRET_DIR?}" -type f -print0 | sort -z | xargs -0 cat)

if [ -n "${ROOT_PASSWORD}" ]; then
  # echo "root:${ROOT_PASSWORD}" | chpasswd
  usermod -p "${ROOT_PASSWORD}" root
  chage -E -1 root
  chage -l root
fi

if [ -n "${SET_RELEASE}" ]; then
  FILE="${SET_RELEASE%:*}"
  CONTENT="${SET_RELEASE#*:}"
  [ -f "${FILE?}" ] && mv "${FILE?}" "${FILE?}.ORIG"
  printf "${CONTENT?}\n" | tee "${FILE?}"
fi

# Install additional packages if provided
if [ -n "${ADD_PACKAGES}" ]; then
  ${PACKAGE_MAKECACHE?}
  pkgs=/tmp/packages; mkdir "${pkgs?}"; cd "${pkgs?}"
  IFS=' ' read -r -a packages <<< "${ADD_PACKAGES}"
  for x in "${!packages[@]}"; do
    if [ "${PKGMGR3?}" = "apt" -a "$(printf "${packages[x]}" | cut -c1-4)" = "http" ]; then
      wget ${packages[x]}
      dpkg -i *.deb
      rm -f *.deb
    else
      ${PACKAGE_INSTALL?} ${packages[x]}
    fi
  done
  cd "${DIR?}"
  rm -rf "${pkgs?}"
fi

${PACKAGE_MAKECACHE?}
# Install systemd & other useful packages
${PACKAGE_INSTALL?} binutils file gzip tar vim hostname procps psmisc curl wget sudo
if [ "${PKGMGR3?}" = "apt" ]; then
  ${PACKAGE_INSTALL?} gpg dirmngr gpg-agent xz-utils
else
  ${PACKAGE_INSTALL?} xz
fi

# Run all setup scripts
find "${INSTALL_SCRIPTS_DIR?}" -type f -print0 | sort -z | xargs -I {} -0 /bin/bash -c '[ -x "{}" ] && "{}"'

if [ "${PKGMGR3?}" = "zyp" ]; then
  if ! getent passwd mail &>/dev/null; then
    groupadd -g 8 mail
    useradd -d /var/spool/mail -s /usr/sbin/nologin -g mail -u 8 mail
    chown root:mail /var/spool/mail
  fi

  if ! getent passwd bin &>/dev/null; then
    groupadd -g 2 bin
    useradd -d /bin -s /usr/sbin/nologin -g bin -u 2 bin
  fi
fi

${PACKAGE_CLEAN?}

# Save configs
"${DIR?}/configs_save.sh"
