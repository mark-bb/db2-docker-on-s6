#!/bin/bash
#
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "${DIR?}/../scripts/utils.sh"

[ "${PKGMGR3?}" = "apt" -a ! -d "/run/sshd" ] && mkdir /run/sshd
/usr/bin/ssh-keygen -A
