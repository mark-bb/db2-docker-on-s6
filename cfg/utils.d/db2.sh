#!/bin/bash
#
# FUNCTION: Common constants & functions
#

###########
# Constants
###########

DB2INSTANCE=db2inst1
: ${DB2PORT="50000"}
DB2INSTANCE_UID=1000
DB2IGROUP=db2iadm1
DB2IGROUP_GID=1000
DB2_HOME="${BASEUSERDIR?}/${DB2INSTANCE?}/sqllib"
PRE_START_SCRIPT_DIR="/database/scripts/pre-start"
POST_START_SCRIPT_DIR="/database/scripts/post-start"
