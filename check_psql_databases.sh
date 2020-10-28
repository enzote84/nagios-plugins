#!/bin/bash
#
# Plugin para verificar que se puedan establecer conexiones a todas las BDs.
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_psql_databases.sh
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
  echo "Description: Plugin para verificar que se puedan establecer conexiones a todas las BDs."
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
  OKDBS=""
  ERRORDBS=""
  MAXERROR=0
  PERFORMANCE=""
  for db in ${DBLIST}; do
    psql ${db} -c "" > /dev/null 2>&1
    CANCONNECT=$?
    printVerbose "DB: ${db}, CANCONNECT: ${CANCONNECT}"
    if [[ ${CANCONNECT} -ne 0 ]]; then
      MAXERROR=${STATE_CRITICAL}
      ERRORDBS="${ERRORDBS} ${db}"
    else
      OKDBS="${OKDBS} ${db}"
    fi
    PERFORMANCE="${PERFORMANCE} ${db}=${CANCONNECT}"
  done
  printVerbose "MAXERROR: ${MAXERROR}"
  printVerbose "OKDBS: ${OKDBS}"
  printVerbose "ERRORDBS: ${ERRORDBS}"
  # Compare max error code:
  if [[ ${MAXERROR} -eq ${STATE_OK} ]]; then
    RESULTMSG="OK - Se logró la conexión a todas las bases de datos: ${OKDBS} | ${PERFORMANCE}"
    RESULTCODE=${STATE_OK}
  else
    RESULTMSG="CRITICAL - No se pudo conectar con las siguientes bases de datos: ${ERRORDBS} | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
  
else
  RESULTMSG="UNKNOWN - No se puede conectar al servicio Postgres"
  RESULTCODE=${STATE_UNKNOWN}
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

