#!/bin/bash
#
# Check connections limits for PostgreSQL
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_psql_connections.sh -w 75 -c 90
#
# Requiremens:
#  - User nrpe should be able to sudo to postgres
#    Example visudo:
#    nrpe    ALL=(postgres)  NOPASSWD: ALL
#
# Example nrpe command definition:
# command[check_psql_connections]=sudo -u postgres /usr/lib64/nagios/plugins/bbr/check_psql_connections.sh
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
  echo "Description: Check connections limits for PostgreSQL."
  echo ""
  echo "Usage: ${PROGNAME} [-w <free % warning>] [-c <free % critical>] | [-V | -h] <COMPLETAR>"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -w [VALUE]      Optional. Connections warning percent limit. Default: 75"
  echo "  -c [VALUE]      Optional. Connections critical percent limit. Default: 90"
  echo "  --verbose-mode  Critical free memory value in %"
  echo ""
  echo "Example: ${PROGNAME} -w 75 -c 90"
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
WARNCONN=75
CRITCONN=90
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
      WARNCONN=$1
      ;;
    -c)
      shift
      CRITCONN=$1
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
printVerbose "Warning limit: ${WARNCONN}%"
printVerbose "Critical limit: ${CRITCONN}%"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

# Load profile:
. ~/.bash_profile

# Query max connections:
MAXIMO=$(psql -tA -d postgres -c 'show max_connections');
if [[ $? != 0 ]]; then
  echo "UNKNOWN - Error al obtener el máximo de conexiones"
  exit ${STATE_UNKNOWN}
fi
printVerbose "Max connections: ${MAXIMO}"

# Query connections:
CONEXIONES=$(psql -tA -d postgres -c 'select count (1) from pg_stat_activity');
if [[ $? != 0 ]]; then
  echo "UNKNOWN - Error al obtener el número de conexiones actuales"
  exit ${STATE_UNKNOWN}
fi
printVerbose "Current connections: ${CONEXIONES}"

# Calculate percent value:
OPERACION=$(expr ${CONEXIONES} \* 100 / ${MAXIMO})
printVerbose "Connections percent: ${OPERACION}"

# Performance metric:
PERFORMANCE="connections=${OPERACION}%;${WARNCONN};${CRITCONN}"

# Evaluate result:
RETVAL=${STATE_OK}
MSGVAL="OK"
if [[ ${OPERACION} -gt ${CRITCONN} ]]; then
  RETVAL=${STATE_CRITICAL}
  MSGVAL="CRITICAL"
else
  if [[ ${OPERACION} -gt ${WARNCONN} ]]; then
    RETVAL=${STATE_WARNING}
    MSGVAL="WARNING"
  fi
fi

# Report:
echo "${MSGVAL} - Conexiones a la BD al ${OPERACION}% | ${PERFORMANCE}"
exit $RETVAL

