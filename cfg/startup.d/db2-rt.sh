#!/bin/bash
#
set -x
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "${DIR?}/../scripts/utils.sh"
. "${ENV_FILES_DIR?}/db2-rt.sh"

[ -n "${DB2INST1_PASSWORD}" ] && usermod -p "${DB2INST1_PASSWORD?}" ${DB2INSTANCE?}

[ -d "${DATADIR?}" ] || mkdir -p "${DATADIR?}"
[ -d "${DATADIR?}/${DB2INSTANCE?}" ] || install -m 775 -o ${DB2INSTANCE?} -g $(id -g ${DB2INSTANCE?}) -d "${DATADIR?}/${DB2INSTANCE?}"
