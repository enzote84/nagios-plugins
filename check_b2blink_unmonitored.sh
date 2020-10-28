#!/bin/bash
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
CONTACT="soporte@bbr.cl"
PROGNAME=$(basename $0)
BASEDIR=$(dirname $0)

print_version() {
  echo ""
  echo "Version: ${VERSION}, Author: ${AUTHOR}, Contact: ${CONTACT}"
  echo ""
}

print_usage() {
  echo ""
  echo "${PROGNAME}"
  print_version
  echo "Description: Plugin para verificar que no todas las compañías con monitoreo activo en B2BLink se estén monitorizando en Nagios"
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
  # Get company id:
  QUERY_COMPANYIDS="select \
    distinct CO.ID \
    from CONTRACTED_SERVICE as CS \
    join COMPANY as CO on CS.COMPANY_ID = CO.ID \
    where CS.ACTIVE is TRUE and CS.MONITOR is TRUE;"
  IDS=$(psql -tA -F "," -c "${QUERY_COMPANYIDS}" -d m2m)
  printVerbose "COMPANY IDS: ${IDS}"
  # For each id, check if it has the status file:
  STATUS=0
  COMPANIES_NOTMONITORED=""
  for id in ${IDS}; do
    # Find if file was modified at least 24 hours ago:
    ISOK=$(find /tmp -name "check_b2blink_pendingmsg_${id}.status" -mtime -1 | wc -l)
    if [[ ${ISOK} -eq 0 ]]; then
      STATUS=$(($STATUS + 1))
      QUERY_COMPANY_NAME="select \
        distinct CO.NAME \
        from COMPANY as CO \
        where CO.ID = ${id};"
      COMPANY_NAME=$(psql -tA -F "," -c "${QUERY_COMPANY_NAME}" -d m2m)
      printVerbose "COMPANY NAME: ${COMPANY_NAME}"
      if [[ ${COMPANIES_NOTMONITORED} == "" ]]; then
        COMPANIES_NOTMONITORED="${COMPANY_NAME}"
      else
        COMPANIES_NOTMONITORED="${COMPANIES_NOTMONITORED}, ${COMPANY_NAME}"
      fi
    fi
  done
  # Evalueate status:
  printVerbose "STATUS: ${STATUS}"
  PERFORMANCE="notmonitored=${STATUS}"
  if [[ ${STATUS} -eq 0 ]]; then
    RESULTMSG="OK - Todas las compañías están siendo monitorizadas en Nagios. | ${PERFORMANCE}"
    RESULTCODE=${STATE_OK}
  else
    RESULTMSG="WARNING - Existen ${STATUS} compañías que no se están monitorizando en Nagios: ${COMPANIES_NOTMONITORED}. | ${PERFORMANCE}"
    RESULTCODE=${STATE_WARNING}
  fi
else
  RESULTMSG="UNKNOWN - No se puede conectar al servicio Postgres"
  RESULTCODE=${STATE_UNKNOWN}
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

