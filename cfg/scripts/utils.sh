#!/bin/bash
#
# FUNCTION: Common constants & functions
#

###########
# Constants
###########

set -a
CONFIG_LIST_FILE=/setup/configs.txt
SCRIPTS_DIR=/setup/scripts
INSTALL_SCRIPTS_DIR=/setup/install.d
STARTUP_SCRIPTS_DIR=/setup/startup.d
SHUTDOWN_SCRIPTS_DIR=/setup/shutdown.d
ENV_FILES_DIR=/setup/utils.d
DISTRIB_DIR=/tmp/distrib
BACKUP_DIR=/setup/backup

if command -v apt-get &>/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  PACKAGE_INSTALL="apt-get -y --no-install-recommends install"
  PACKAGE_MAKECACHE="apt-get update"
  PACKAGE_CLEAN="apt-get clean"
elif command -v dnf &>/dev/null; then
  PACKAGE_INSTALL="dnf -y install"
  PACKAGE_MAKECACHE="dnf makecache"
  PACKAGE_CLEAN="dnf clean all"
elif command -v yum &>/dev/null; then
  PACKAGE_INSTALL="yum -y install"
  PACKAGE_MAKECACHE="yum makecache"
  PACKAGE_CLEAN="yum clean all"
elif command -v zypper &>/dev/null; then
  PACKAGE_INSTALL="zypper install -y --no-recommends"
  PACKAGE_MAKECACHE="zypper refresh"
  PACKAGE_CLEAN="zypper clean --all"
else
  echo "Unknown package manager" >&2
  exit 1
fi

PKGMGR3=$(printf "${PACKAGE_INSTALL?}" | cut -c1-3)
set +a
