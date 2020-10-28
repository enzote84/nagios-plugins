#!/bin/bash
#
# Nagios script to check storage usage on ActiveMQ
#
# Version: 1.0
# Author: BBR
# Support: soporte@bbr.cl
#
# Example usage:
#   ./check_activemq.sh -w 80 -c 90 -H 10.0.22.1
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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
  echo "Version: $VERSION, Author: $AUTHOR"
  echo ""
}

print_usage() {
  echo ""
  echo "$PROGNAME"
  echo "Version: $VERSION"
  echo ""
  echo "Usage: $PROGNAME [-H <ip|fqdn> -w <warning_uasge> -c <critical_usage> [-u 'user:passwd'] [--verbose-mode] ] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -H              IP or fqdn of ActiveMQ host"
  echo "  -w              Maximum usage percentage for a warning"
  echo "  -c              Maximum usage percentage for a critical"
  echo "  -u              Optional. User authentication: user:passwd. Default: admin:admin"
  echo "  --verbose-mode  Optional. Verbose output"
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
# Make sure the correct number of command line arguments have been supplied
if [[ $# -lt 1 ]]; then
  print_usage
  exit $STATE_UNKNOWN
fi
# Defaults:
USERPASSWD="admin:admin"
VERBOSE=0
# Grab the command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h)
      print_usage
      exit $STATE_OK
      ;;
    -V)
      print_version
      exit $STATE_OK
      ;;
    -H)
      shift
      HOSTIP=$1
      ;;
    -w)
      shift
      WARNUSAGE=$1
      ;;
    -c)
      shift
      CRITUSAGE=$1
      ;;
    -u)
      shift
      USERPASSWD=$1
      ;;
    --verbose-mode)
      VERBOSE=1
      ;;
    *)
      echo "Unknown argument: $1"
      print_usage
      exit $STATE_UNKNOWN
      ;;
  esac
  shift
done

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for mandatory parameters
#
if [[ -z ${HOSTIP} ]] || [[ -z ${WARNUSAGE} ]] || [[ -z ${CRITUSAGE} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi
printVerbose "Host:     ${HOSTIP}"
printVerbose "Warning:  ${WARNUSAGE}"
printVerbose "Critical: ${CRITUSAGE}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Commands and variables
#

# Check variables:
HIGHERERROR=0
PERFORMANCE=""
# Curl:
TIMEOUT=4
CURLFMT="/tmp/check_activemq_curl_format_$$.txt"
echo "%{time_total}\n" > ${CURLFMT}
# Errors:
ERRORS="/tmp/check_activemq_errors_$$.tmp"
# Stats information:
STATSFILE="/tmp/check_activemq_stats_$$.tmp"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

# Check connection to URL:
RESPONSETIME=$(curl -w "@${CURLFMT}" --connect-timeout "${TIMEOUT}" -o /dev/null -s "http://${HOSTIP}:8161/admin/index.jsp")
printVerbose "Response time: ${RESPONSETIME}"
RESPONSETIME=$(echo "${RESPONSETIME}" | cut -d',' -f1)
# Delete curl format:
rm ${CURLFMT}
# Check response time:
if [[ ${RESPONSETIME} -ge ${TIMEOUT} ]]; then
  echo "UNKNOWN - Host ${HOSTIP} no responde"
  exit ${STATE_UNKNOWN}
fi

# Get stats information:
curl -s --get --output "${STATSFILE}" --connect-timeout "${TIMEOUT}" --user "${USERPASSWD}" --url "http://${HOSTIP}:8161/admin/index.jsp"
if [[ ! -s "${STATSFILE}" ]]; then
  echo "OK - ActiveMQ en modo esclavo"
  exit ${STATE_OK}
fi

# Process stats:
STOREPCTUSED=$(sed -n '/<table>/,/<\/table>/p' "${STATSFILE}" | sed 's/^[\ \t]*//g' | tr -d '\n' | sed 's/<\/TR[^>]*>/\n/Ig'  | sed 's/<\/\?\(TABLE\|TBODY\|TR\|TH\|A\|B\)[^>]*>//Ig' | sed 's/^<T[DH][^>]*>\|<\/\?T[DH][^>]*>$//Ig' | sed 's/<\/T[DH][^>]*><T[DH][^>]*>/,/Ig' | grep "Store percent used" | cut -d',' -f2)
printVerbose "Store percent used: ${STOREPCTUSED}"
MEMORYPCTUSED=$(sed -n '/<table>/,/<\/table>/p' "${STATSFILE}" | sed 's/^[\ \t]*//g' | tr -d '\n' | sed 's/<\/TR[^>]*>/\n/Ig'  | sed 's/<\/\?\(TABLE\|TBODY\|TR\|TH\|A\|B\)[^>]*>//Ig' | sed 's/^<T[DH][^>]*>\|<\/\?T[DH][^>]*>$//Ig' | sed 's/<\/T[DH][^>]*><T[DH][^>]*>/,/Ig' | grep "Memory percent used" | cut -d',' -f2)
printVerbose "Memory percent used: ${MEMORYPCTUSED}"
TEMPPCTUSED=$(sed -n '/<table>/,/<\/table>/p' "${STATSFILE}" | sed 's/^[\ \t]*//g' | tr -d '\n' | sed 's/<\/TR[^>]*>/\n/Ig'  | sed 's/<\/\?\(TABLE\|TBODY\|TR\|TH\|A\|B\)[^>]*>//Ig' | sed 's/^<T[DH][^>]*>\|<\/\?T[DH][^>]*>$//Ig' | sed 's/<\/T[DH][^>]*><T[DH][^>]*>/,/Ig' | grep "Temp percent used" | cut -d',' -f2)
printVerbose "Temp percent used: ${TEMPPCTUSED}"

# Save performance data:
PERFORMANCE="${PERFORMANCE} store_pct_used=${STOREPCTUSED}%;${WARNUSAGE};${CRITUSAGE};0;100"
PERFORMANCE="${PERFORMANCE} memory_pct_used=${MEMORYPCTUSED}%;${WARNUSAGE};${CRITUSAGE};0;100"
PERFORMANCE="${PERFORMANCE} temp_pct_used=${TEMPPCTUSED}%;${WARNUSAGE};${CRITUSAGE};0;100"

# Compare values to thresholds:
if [[ ${STOREPCTUSED} -gt ${CRITUSAGE} ]]; then
  echo "${STATE_CRITICAL},CRITICAL - El porcentaje utilizado de STORE es ${STOREPCTUSED}%" >> ${ERRORS}
else
  if [[ ${STOREPCTUSED} -gt ${WARNUSAGE} ]]; then
    echo "${STATE_WARNING},WARNING - El porcentaje utilizado de STORE es ${STOREPCTUSED}%" >> ${ERRORS}
  fi
fi
if [[ ${MEMORYPCTUSED} -gt ${CRITUSAGE} ]]; then
  echo "${STATE_CRITICAL},CRITICAL - El porcentaje utilizado de STORE es ${MEMORYPCTUSED}%" >> ${ERRORS}
else
  if [[ ${MEMORYPCTUSED} -gt ${WARNUSAGE} ]]; then
    echo "${STATE_WARNING},WARNING - El porcentaje utilizado de STORE es ${MEMORYPCTUSED}%" >> ${ERRORS}
  fi
fi
if [[ ${TEMPPCTUSED} -gt ${CRITUSAGE} ]]; then
  echo "${STATE_CRITICAL},CRITICAL - El porcentaje utilizado de STORE es ${TEMPPCTUSED}%" >> ${ERRORS}
else
  if [[ ${TEMPPCTUSED} -gt ${WARNUSAGE} ]]; then
    echo "${STATE_WARNING},WARNING - El porcentaje utilizado de STORE es ${TEMPPCTUSED}%" >> ${ERRORS}
  fi
fi

# Check for errors:
TEXTMSG="OK - Todos los storage sin problemas de espacio"
EXITCODE=${STATE_OK}
if [[ -s ${ERRORS} ]]; then
  printFileVerbose ${ERRORS}
  TEXTMSG=$(cat ${ERRORS} | sort -r | cut -d',' -f2)
  EXITCODE=$(cat ${ERRORS} | sort -r | cut -d',' -f1 | head -1)
  rm ${ERRORS}
fi

# Add performance metrics:
TEXTMSG="${TEXTMSG} | ${PERFORMANCE}"

# Report results:
echo "${TEXTMSG}"
exit "${EXITCODE}"

