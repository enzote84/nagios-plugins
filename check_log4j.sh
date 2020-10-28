#!/bin/bash
#
# Check log4j errors
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/bbr/check_log4j.sh -c 10 -t 60 -L /var/log/app.log
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
  echo "Description: Checks for errors en the last -t minutes in a log4j file."
  echo ""
  echo "Usage: ${PROGNAME} -c <critical error count> -t <minutes from now> -L <log4j file name> | [-V | -h]"
  echo ""
  echo "  -h           Show this page"
  echo "  -V           Plugin Version"
  echo "  -c [VALUE]   Critical count threshold"
  echo "  -t [VALUE]   Time in minutes to be consider"
  echo "  -L [NAME]    Full path of the log file"
  echo ""
  echo "Example: ${PROGNAME} -c 10 -t 60 -L /var/log/app.log"
  echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Make sure the correct number of command line arguments have been supplied
if [[ $# -lt 1 ]]; then
  print_usage
  exit ${STATE_UNKNOWN}
fi
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
    -c)
      shift
      CRITCOUNT=$1
      ;;
    -t)
      shift
      TIMEPERIOD=$1
      ;;
    -L)
      shift
      LOGNAME=$1
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
if [[ -z ${CRITCOUNT} ]] || [[ -z ${TIMEPERIOD} ]] || [[ -z ${LOGNAME} ]]; then
  echo "UNKNOWN - Missing parameters"
  print_usage
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if log file exists and is readable
#
if [[ ! -r ${LOGNAME} ]]; then
  echo "Log file ${LOGNAME} does not exists or is not readable. This could also be a missing reading permissions in the file or missing execution permissions in the file path."
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check log file
#

# Get time stamp from TIMEPERIOD minutes ago to use as reference.
# Log entries older than DATEREFERENCE will not be considered.
DATEREFERENCE=$(date --date="-${TIMEPERIOD} minutes" +"%Y-%m-%d-%H:%M:%S")
# Get lines with [ERROR] string and a timestamp greather (newer) than DATEREFERENCE:
# Also add a last lines with the count of errors:
ERRORLINES=$(grep "\[ERROR\]" ${LOGNAME} | awk -v dateref=${DATEREFERENCE} 'BEGIN{sum = 0;}{$1 = substr($1, 4, 10) "-" substr($2, 1, 8); }{ if ($1 >= dateref) {print substr($0, index($0, "[ERROR]") + 8); sum = sum +1;} }END{print sum;}')
# Get the error count number from the list:
ERRORCOUNT=$(echo "${ERRORLINES}" | tail -1)
# Erase the error count from ERRORLINES:
ERRORLINES=$(echo "${ERRORLINES}" | head -n -1)

# Performance metric:
PERFORMANCE="errors=${ERRORCOUNT}"

# Report:
RESULTMSG="OK - No errors found in ${LOGNAME} in the last ${TIMEPERIOD} minutes | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${ERRORCOUNT} -gt 0 ]]; then
  RESULTMSG="WARNING - ${ERRORCOUNT} errors found in ${LOGNAME} in the last ${TIMEPERIOD} minutes: ${ERRORLINES} | ${PERFORMANCE}"
  RESULTCODE=${STATE_WARNING}
  if [[ ${ERRORCOUNT} -ge ${CRITCOUNT} ]]; then
    RESULTMSG="CRITICAL - ${ERRORCOUNT} errors found in ${LOGNAME} in the last ${TIMEPERIOD} minutes: ${ERRORLINES} | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


