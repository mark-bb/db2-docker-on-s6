#!/bin/bash
#
set -x
${PACKAGE_INSTALL?} postfix
${PACKAGE_INSTALL?} mailx
#echo "/etc/postfix" | tee -a "${CONFIG_LIST_FILE?}"
