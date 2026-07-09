#!/bin/bash
#
# FUNCTION: Common constants & functions
#

list_local_dbs() {
  su - ${DB2INSTANCE?} -c "db2 list db directory | awk -v RS='' '/= Indirect/' | awk -F'= ' '/Database alias/{print \$2}'"
}

###########
# Constants
###########

DB2FUSER=db2fenc1
DB2FUSER_UID=1001
DB2FGROUP=db2fadm1
DB2FGROUP_GID=1001
INSTDIR="/tmp/db2"
RSPF="/setup/db2server-rt.rsp"
