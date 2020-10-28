#!/bin/bash
#
# Plugin para verificar que no existan queries con mucho tiempo de ejecución.
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_psql_active_queries.sh
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
  echo "Description: Plugin para verificar que no existan queries con mucho tiempo de ejecución."
  echo ""
  echo "Usage: ${PROGNAME} [-w <warn_minutes>] [-c <crit_minutes>] [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -w VALUE        Optional. Warning threshold minutes. Default: 60."
  echo "  -c VALUE        Optional. Critical threshold minutes. Default: 120."
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
WARNMINUTES=60
CRITMINUTES=120
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
    -w)
      shift
      WARNMINUTES=$1
      ;;
    -c)
      shift
      CRITMINUTES=$1
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
  # Get minutes of running active queries:
  MINUTES=$(psql -x -tA -c "SELECT max(DATE_PART('minute', now()-query_start) + 60 * DATE_PART('hour', now()-query_start)) as minutes FROM pg_stat_activity WHERE state = 'active' AND query NOT LIKE 'COPY %'" | grep 'minutes' | cut -d'|' -f2)
  printVerbose "MINUTES: ${MINUTES}"
  # Performance metric:
  PERFORMANCE="minutes=${MINUTES}m;${WARNMINUTES};${CRITMINUTES}"
  # Compare thresholds:
  if [[ ${MINUTES} -gt ${CRITMINUTES} ]]; then
    RESULTMSG="CRITICAL - Existen queries activas con más de ${CRITMINUTES} minutos corriendo. | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  else
    if [[ ${MINUTES} -gt ${WARNMINUTES} ]]; then
      RESULTMSG="WARNING - Existen queries activas con más de ${WARNMINUTES} minutos corriendo. | ${PERFORMANCE}"
      RESULTCODE=${STATE_WARNING}
    else
      RESULTMSG="OK - No existen queries activas con más de ${WARNMINUTES} minutos corriendo. | ${PERFORMANCE}"
      RESULTCODE=${STATE_OK}
    fi
  fi
  
else
  RESULTMSG="UNKNOWN - No se puede conectar al servicio Postgres"
  RESULTCODE=${STATE_UNKNOWN}
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

