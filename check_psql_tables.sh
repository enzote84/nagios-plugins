#!/bin/bash
#
# Plugin para verificar que se puedan acceder a todas las tablas de las DBs.
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_psql_tables.sh
#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios return codes
#
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Plugin info
#
AUTHOR="BBR"
VERSION="1.0"
PROGNAME=$(basename $0)
BASEDIR=$(dirname $0)

print_version() {
  echo ""
  echo "Version: ${VERSION}, Author: ${AUTHOR}"
  echo ""
}

print_usage() {
  echo ""
  echo "${PROGNAME}"
  echo "Version: ${VERSION}"
  echo "Description: Plugin para verificar que se puedan acceder a todas las tablas de las DBs."
  echo ""
  echo "Usage: ${PROGNAME} [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME}"
  echo ""
}

printVerbose() {
  if [[ ${VERBOSE} -eq 1 ]]; then
    echo "$1"
  fi
}

printFileVerbose() {
  if [[ ${VERBOSE} -eq 1 ]]; then
    cat "$1"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Defaults:
VERBOSE=0
# Grab the command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h)
      print_usage
      exit ${STATE_OK}
      ;;
    -V)
      print_version
      exit ${STATE_OK}
      ;;
    --verbose-mode)
      VERBOSE=1
      ;;
    *)
      echo "Unknown argument: $1"
      print_usage
      exit ${STATE_UNKNOWN}
      ;;
  esac
  shift
done

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

# Load profile:
. ~/.bash_profile

# Verify that the service is running:
psql -c "" > /dev/null 2>&1
ISRUNNING=$?
printVerbose "ISRUNNING: ${ISRUNNING}"
if [[ ${ISRUNNING} -eq 0 ]]; then
  # Get DB list:
  DBLIST=$(psql -A -c 'SELECT datname FROM pg_catalog.pg_database;' |egrep -vi 'rows|filas|template|datname|postgres')
  printVerbose "DBLIST: ${DBLIST}"
  # Iterate over each DB and try to connect to it:
  ERRORDBS=""
  ERRORTABLES=""
  MAXERRORDB=${STATE_OK}
  MAXERRORTABLE=${STATE_OK}
  PERFORMANCE=""
  for db in ${DBLIST}; do
    psql ${db} -c "" > /dev/null 2>&1
    CANCONNECT=$?
    printVerbose "DB: ${db}, CANCONNECT: ${CANCONNECT}"
    if [[ ${CANCONNECT} -ne 0 ]]; then
      MAXERRORDB=${STATE_UNKNOWN}
      ERRORDBS="${ERRORDBS} ${db}"
    else
      # Get table list for this database:
      TABLELIST=$(psql ${db} -tAc "select table_schema, table_name from  information_schema.tables where table_type='BASE TABLE' and table_schema!='pg_catalog' and table_schema!='information_schema';"|tr -t '|' '.'|grep -vi vdp. | grep -vi vwp. | grep -vi vmp.| grep -vi public.ventadc | grep -vi public.ventamc | grep -vi public.ventawp )
      printVerbose "TABLELIST for ${db}: ${TABLELIST}"
      # Iterate over each table and try to SELECT:
      MAXERRORCOUNT=0
      for table in ${TABLELIST}; do
        psql ${db} -tAc "SELECT 1 from ${table} limit 1;" > /dev/null 2>&1
        CANSELECT=$?
        printVerbose "CANSELECT for ${db} - ${table}: ${CANSELECT}"
        if [[ ${CANSELECT} -ne 0 ]]; then
          MAXERRORTABLE=${STATE_WARNING}
          MAXERRORCOUNT=$((${MAXERRORCOUNT} + 1))
          ERRORTABLES="${ERRORTABLES} ${db}::${table}"
        fi
        
      done
      printVerbose "MAXERRORCOUNT for ${db}: ${MAXERRORCOUNT}"
      PERFORMANCE="${PERFORMANCE} ${db}=${MAXERRORCOUNT}"
    fi
  done
  printVerbose "MAXERRORDB: ${MAXERRORDB}"
  printVerbose "ERRORDBS: ${ERRORDBS}"
  printVerbose "MAXERRORTABLE: ${MAXERRORTABLE}"
  printVerbose "ERRORTABLES: ${ERRORTABLES}"
  # Compare max error code:
  if [[ ${MAXERRORDB} -ne ${STATE_OK} ]]; then
    RESULTMSG="UNNKNOWN - No se pudo conectar con las siguientes bases de datos: ${ERRORDBS} | ${PERFORMANCE}"
    RESULTCODE=${STATE_UNKNOWN}
  else
    if [[ ${MAXERRORTABLE} -ne ${STATE_OK} ]]; then
      RESULTMSG="WARNING - No se pudo hacer SELECT a las siguientes tablas: ${ERRORTABLES} | ${PERFORMANCE}"
      RESULTCODE=${STATE_WARNING}
    else
      RESULTMSG="OK - Se logró hacer SELECT a todas las tablas | ${PERFORMANCE}"
      RESULTCODE=${STATE_OK}
    fi
  fi
  
else
  RESULTMSG="UNKNOWN - No se puede conectar al servicio Postgres"
  RESULTCODE=${STATE_UNKNOWN}
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

