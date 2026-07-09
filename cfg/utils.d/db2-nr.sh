#!/bin/bash
#
# FUNCTION: Common constants & functions
#

list_local_dbs() {
  db2 list db directory | awk -v RS='' '/= Indirect/' | awk -F'= ' '/Database alias/{print $2}'
}

###########
# Constants
###########

DB2INSTANCE=db2inst1
: ${DB2INST1_PASSWORD="passw0rd"}
: ${DB2PORT="50000"}
DB2INSTANCE_UID=1000
DB2IGROUP=db2iadm1
DB2IGROUP_GID=1000
CONFDIR=/database/config
DATADIR=/database/data
USERHOME="${CONFDIR?}/${DB2INSTANCE?}"
DB2_HOME="${USERHOME?}/sqllib"
INSTDIR="/distrib/db2"
RSPF="/setup/db2server-nr.rsp"
RFEF="/setup/db2rfe.cfg"
PRE_START_SCRIPT_DIR="/database/scripts/pre-start"
POST_START_SCRIPT_DIR="/database/scripts/post-start"
