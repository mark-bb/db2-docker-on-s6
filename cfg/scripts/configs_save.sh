#!/bin/bash
#
set -x
[ -f "${CONFIG_LIST_FILE?}" ] || exit 0

while IFS= read -r obj; do
  cp -a --parents "${obj?}" "${BACKUP_DIR?}"
done < "${CONFIG_LIST_FILE?}"
