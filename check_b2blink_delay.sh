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
  echo "Description: Plugin para verificar que no hay atraso en el módulo de monitoreo de B2BLink con los B2B"
  echo ""
  echo "Usage: ${PROGNAME} -S 'SITE NAME' [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -S              Site name"
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
WARN_MINUTES=90
CRIT_MINUTES=180
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
    -S)
      shift
      SITE_NAME=$1
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
# Check for mandatory parameters
#
if [[ -z ${SITE_NAME} ]]; then
  echo "UNKNOWN - Missing parameters: -S 'SITE NAME'"
  exit ${STATE_UNKNOWN}
fi
printVerbose "SITE NAME: '${SITE_NAME}'"

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
  # Check that site exists:
  QUERY_SITE="select SI.ID as SITEID from SITE AS SI where SI.NAME = '${SITE_NAME}';"
  SITE_EXISTS=$(psql -tA -F "," -c "${QUERY_SITE}" -d m2m | wc -l)
  printVerbose "SITE ID: ${SITE_EXISTS}"
  if [[ ${SITE_EXISTS} -eq 0 ]]; then
    RESULTMSG="UNKNOWN - No se encontró el sitio ${SITE_NAME} en la base de datos."
    RESULTCODE=${STATE_UNKNOWN}
  else
    # Get delay for this site:
    QUERY_DELAY="select \
        round(max(extract (EPOCH from(NOW() - CS.LAST_MONITORED)) / 60)) as ATRASO \
      from \
        CONTRACTED_SERVICE as CS \
        join SITE AS SI ON CS.SITE_ID = SI.ID \
      where \
        CS.ACTIVE is TRUE and \
        CS.MONITOR is TRUE and \
        SI.NAME = '${SITE_NAME}' \
      group by SI.NAME ;"
    SITE_DELAY=$(psql -tA -F "," -c "${QUERY_DELAY}" -d m2m)
    printVerbose "SITE DELAY: ${SITE_DELAY}"
    HOURS_DELAY="$(($SITE_DELAY / 60))"
    DAYS_DELAY="$(($HOURS_DELAY / 24))"
    HOURS_DELAY="$(($HOURS_DELAY % 24))"
    MINUTES_DELAY="$(($SITE_DELAY % 60))"
    PERFORMANCE="delay=${SITE_DELAY}m"
    if [[ ${SITE_DELAY} -gt ${CRIT_MINUTES} ]]; then
      RESULTMSG="CRITICAL - Hay un atraso de ${DAYS_DELAY}d:${HOURS_DELAY}h:${MINUTES_DELAY}m en el monitoreo para el sitio ${SITE_NAME}. | ${PERFORMANCE}"
      RESULTCODE=${STATE_CRITICAL}
    else
      if [[ ${SITE_DELAY} -gt ${WARN_MINUTES} ]]; then
        RESULTMSG="WARNING - Hay un atraso de ${SITE_DELAY} minutos en el monitoreo para el sitio ${SITE_NAME}. | ${PERFORMANCE}"
        RESULTCODE=${STATE_WARNING}
      else
        RESULTMSG="OK - No hay atrasos en el monitoreo para el sitio ${SITE_NAME}. | ${PERFORMANCE}"
        RESULTCODE=${STATE_OK}
      fi
    fi
  fi
else
  RESULTMSG="UNKNOWN - No se puede conectar al servicio Postgres"
  RESULTCODE=${STATE_UNKNOWN}
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

