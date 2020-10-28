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
  echo "Description: Plugin para verificar que no hay OC pendientes en B2BLink"
  echo ""
  echo "Usage: ${PROGNAME} -C 'COMPANY NAME' [-w <warning count>] [-c <critical count>] [--no-provider-type] [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h                  Show this page"
  echo "  -V                  Plugin Version"
  echo "  -C                  Company name"
  echo "  -w                  Optional. Warning count. Default: 1. Warning at first try"
  echo "  -c                  Optional. Critical count. Default: 3. Critical at third try"
  echo "  --no-provider-type  Optional. Do not search for integration type (Perú)."
  echo "  --verbose-mode      Optional. Turn on verbose mode"
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
NOPROVIDER=0
WARN_COUNT=1
CRIT_COUNT=3
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
    -C)
      shift
      COMPANY_NAME=$1
      ;;
    -w)
      shift
      WARN_COUNT=$1
      ;;
    -c)
      shift
      CRIT_COUNT=$1
      ;;
    --no-provider-type)
      NOPROVIDER=1
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
if [[ -z ${COMPANY_NAME} ]]; then
  echo "UNKNOWN - Missing parameters: -C 'COMPANY NAME'"
  exit ${STATE_UNKNOWN}
fi
printVerbose "COMPANY NAME: '${COMPANY_NAME}'"

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
  QUERY_COMPANYID="select CO.ID from COMPANY as CO where CO.NAME = '${COMPANY_NAME}';"
  COMPANY_ID=$(psql -tA -F "," -c "${QUERY_COMPANYID}" -d m2m)
  printVerbose "COMPANY ID: ${COMPANY_ID}"
  # Check status file:
  STATUS_FILE="/tmp/check_b2blink_pendingmsg_${COMPANY_ID}.status"
  if [[ ! -r ${STATUS_FILE} ]]; then
    echo "0" > ${STATUS_FILE}
  fi
  # Get pending messages:
  QUERY_PENDINGMSG="select \
      sum(CS.PENDING_MSGS) as PENDINGMESSAGES \
    from \
      CONTRACTED_SERVICE as CS \
      join COMPANY as CO on CS.COMPANY_ID = CO.ID \
    where \
      CS.ACTIVE is TRUE and \
      CS.MONITOR is TRUE and \
      CO.NAME = '${COMPANY_NAME}' ;"
  PENDINGMSG=$(psql -tA -F "," -c "${QUERY_PENDINGMSG}" -d m2m)
  printVerbose "PENDINGMSG: ${PENDINGMSG}"
  # Get company RUT:
  QUERY_RUT="select CO.RUT as RUT from COMPANY as CO where CO.NAME = '${COMPANY_NAME}';"
  RUT=$(psql -tA -F "," -c "${QUERY_RUT}" -d m2m)
  printVerbose "RUT: ${RUT}"
  # Performance metrics:
  PERFORMANCE="pendingmsg=${PENDINGMSG}"
  # Get company folder type
  FOLDERTYPE=""
  if [[ NOPROVIDER -eq 0 ]]; then
    QUERY_FOLDERTYPE="select distinct \
      FT.description \
    from \
      CONTRACTED_SERVICE as CS \
      join COMPANY as CO on CS.COMPANY_ID = CO.ID \
      join MESSAGEFOLDER as MF on CS.folder_id = MF.id \
      join MESSAGEFOLDERTYPE as FT on MF.messagefoldertype_id = FT.id \
    where \
      CS.ACTIVE is TRUE and \
      CS.MONITOR is TRUE and \
      CO.NAME = '${COMPANY_NAME}';"
    FOLDERTYPE=$(psql -tA -F "," -c "${QUERY_FOLDERTYPE}" -d m2m)
  fi
  printVerbose "FOLDERTYPE: ${FOLDERTYPE}"
  if [[ ${PENDINGMSG} -gt 0 ]]; then
    # Get which sites are having pending messages:
    QUERY_SITES="select \
      concat(SI.NAME, ' (', CS.PENDING_MSGS, ')') as SITENAME \
    from \
      CONTRACTED_SERVICE as CS \
      join SITE AS SI ON CS.SITE_ID = SI.ID \
      join COMPANY as CO on CS.COMPANY_ID = CO.ID \
    where \
      CS.ACTIVE is TRUE and \
      CS.MONITOR is TRUE and \
      CS.PENDING_MSGS > 0 and \
      CO.NAME = '${COMPANY_NAME}';"
    SITES=$(psql -tA -F "," -c "${QUERY_SITES}" -d m2m | sed -e 'H;${x;s/\n/, /g;s/^,//;p;};d')
    printVerbose "SITES: ${SITES}"
    # Check if it is the first time in this condition:
    STATUS=$(cat ${STATUS_FILE})
    printVerbose "STATUS: ${STATUS}"
    if [[ ${STATUS} -ge ${CRIT_COUNT} ]]; then
      RESULTMSG="CRITICAL - Existen ${PENDINGMSG} mensajes pendientes para ${COMPANY_NAME} (RUT: ${RUT}) (${FOLDERTYPE}). Los sitios afectados son: ${SITES}. | ${PERFORMANCE}"
      RESULTCODE=${STATE_CRITICAL}
    else
      if [[ ${STATUS} -ge ${WARN_COUNT} ]]; then
        RESULTMSG="WARNING - Existen ${PENDINGMSG} mensajes pendientes para ${COMPANY_NAME} (RUT: ${RUT}) (${FOLDERTYPE}). Los sitios afectados son: ${SITES}. | ${PERFORMANCE}"
        RESULTCODE=${STATE_WARNING}
      else
        RESULTMSG="OK - Existen ${PENDINGMSG} mensajes pendientes para ${COMPANY_NAME} (RUT: ${RUT}) (${FOLDERTYPE}). Los sitios afectados son: ${SITES}. | ${PERFORMANCE}"
        RESULTCODE=${STATE_OK}
      fi
    fi
    STATUS=$(($STATUS + 1))
    echo "${STATUS}" > ${STATUS_FILE}
  else
    RESULTMSG="OK - No existen mensajes pendientes para ${COMPANY_NAME} (RUT: ${RUT}) (${FOLDERTYPE}). | ${PERFORMANCE}"
    RESULTCODE=${STATE_OK}
    echo "0" > ${STATUS_FILE}
  fi
else
  RESULTMSG="UNKNOWN - No se puede conectar al servicio Postgres"
  RESULTCODE=${STATE_UNKNOWN}
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

