#!/bin/bash
#
# Check S3 errors in log file
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/bbr/check_s3log.sh -c 10 -t 60
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
  echo "Description: Checks for errors en the last -t minutes in a S3 log file."
  echo ""
  echo "Usage: ${PROGNAME} [-c <critical error count>] [-t <minutes from now>] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -c [VALUE]      Optional. Critical count threshold. Default: 10"
  echo "  -t [VALUE]      Optional. Time in minutes to be consider. Default: 60"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME} -c 10 -t 60"
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
CRITCOUNT=10
TIMEPERIOD=60
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
# Check if log file exists and is readable
#
LOGDATE=$(date --date="-${TIMEPERIOD} minutes" "+%Y%m%d")
printVerbose "LOGDATE: ${LOGDATE}"
LOGNAME="/var/log/s3-policy-${LOGDATE}.log"
if [[ ! -r ${LOGNAME} ]]; then
  echo "Log file ${LOGNAME} does not exists or is not readable. This could also be a missing reading permissions in the file or missing execution permissions in the file path."
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if file was updated in the last TIMEPERIOD + 10 minutes
#
WASMODIFIED=$(find ${LOGNAME} -mmin -$((TIMEPERIOD + 10)) | wc -l)
printVerbose "WASMODIFIED: ${WASMODIFIED}"
if [[ ${WASMODIFIED} -eq 0 ]]; then
  echo "Log file ${LOGNAME} was not modified in the last $((TIMEPERIOD + 10)) minutes. Please check if the crontab service is running."
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for errors in log file
#

# Get time stamp from TIMEPERIOD minutes ago to use as reference.
# Log entries older than DATEREFERENCE will not be considered.
DATEREFERENCE=$(date --date="-${TIMEPERIOD} minutes" +"%Y-%m-%dT%H:%M:%S")
printVerbose "DATEREFERENCE: ${DATEREFERENCE}"
# Get lines with [ERROR] string and a timestamp greather (newer) than DATEREFERENCE:
# Also add a last lines with the count of errors:
ERRORLINES=$(awk -v dateref="${DATEREFERENCE}" 'BEGIN{sum = 0;}{$2 = substr($2, 2, 19); }{if ($1 == "E," && $2 >= dateref){sum = sum +1; print substr($0, index($0, "-- :") + 5);}}END{print sum;}' ${LOGNAME})
printVerbose "ERRORLINES: ${ERRORLINES}"
# Get the error count number from the list:
ERRORCOUNT=$(echo "${ERRORLINES}" | tail -1)
printVerbose "ERRORCOUNT: ${ERRORCOUNT}"
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


