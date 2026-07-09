#!/bin/bash
#
# Function: Restores files & directories to the mounted ones if they are empty
#
set -x
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "${DIR?}/utils.sh"
[ -f "${CONFIG_LIST_FILE?}" ] || exit 0

cd "${BACKUP_DIR?}"
while IFS= read -r obj; do
  rel_path="$(printf "${obj?}" | cut -c2-)"
  if [ -d "${BACKUP_DIR?}/${rel_path?}" -a -z "$(ls -A "${obj?}")" ]; then
    cp -a --parents "${rel_path?}" / 
  elif [ -f "${BACKUP_DIR?}/${rel_path?}" -a $(stat -c %s "${obj?}") -eq 0 ]; then
    cp -a "${rel_path?}" / 
  fi
  # Permissions and owners
  # chmod $(stat -c %a "${BACKUP_DIR?}/${rel_path?}") "${obj?}"
  # chown $(stat -c %U "${BACKUP_DIR?}/${rel_path?}"):$(stat -c %G "${BACKUP_DIR?}/${rel_path?}") "${obj?}"
done < "${CONFIG_LIST_FILE?}"
