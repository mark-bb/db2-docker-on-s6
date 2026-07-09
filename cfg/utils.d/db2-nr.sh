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

INSTDIR="/distrib/db2"
RSPF="/setup/db2server-nr.rsp"
RFEF="/setup/db2rfe.cfg"
