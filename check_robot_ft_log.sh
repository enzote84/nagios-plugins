#!/bin/bash
#
# Check errors in log from robot_ft
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/bbr/check_robot_ft_log.sh -c 10 -t 60 -D /home/bbrapp/IRS/progs/robot_ft/log/ -s "SQLSTATE=08003"
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
  echo "Description: Checks for errors en the last -t minutes in a log file from robot_ft."
  echo ""
  echo "Usage: ${PROGNAME} -c <critical error count> -t <minutes from now> -s <error string> -L <log4j file name> [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -c [VALUE]      Critical count threshold"
  echo "  -t [VALUE]      Time in minutes to be consider"
  echo "  -s [STRING]     String containing the error text to find"
  echo "  -D [PATH]       Full path of the logs' directory"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME} -c 10 -t 60 -D /home/bbrapp/IRS/progs/robot_ft/log/ -s \"SQLSTATE=08003\""
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
  exit ${STATE_UNKNOWN}
fi
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
    -c)
      shift
      CRITCOUNT=$1
      ;;
    -t)
      shift
      TIMEPERIOD=$1
      ;;
    -s)
      shift
      ERRORSTR=$1
      ;;
    -D)
      shift
      DIRNAME=$1
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
printVerbose "Log directory: ${DIRNAME}"
printVerbose "Critical: ${CRITCOUNT} hits"
printVerbose "Time period: ${TIMEPERIOD} minutes"
printVerbose "Error string: ${ERRORSTR}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for mandatory parameters
#
if [[ -z ${CRITCOUNT} ]] || [[ -z ${TIMEPERIOD} ]] || [[ -z ${ERRORSTR} ]] || [[ -z ${DIRNAME} ]]; then
  echo "UNKNOWN - Missing parameters"
  print_usage
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if log directory exists and is readable
#
if [[ ! -d ${DIRNAME} ]]; then
  echo "Log directory ${DIRNAME} does not exists or is not readable. This could also be a missing reading permissions in the file or missing execution permissions in the file path."
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check log files
#

# Initialize counts:
ERRORSRECEPTOR=0
ERRORSENVIADOR=0

# Get DATE from today and yesterday:
DATETODAY=$(date +%Y%m%d)
DATEYESTERDAY=$(date --date="-1 day" +%Y%m%d)
printVerbose "Date today: ${DATETODAY}"
printVerbose "Date yesterday: ${DATEYESTERDAY}"

# Get time stamp from TIMEPERIOD minutes ago to use as reference.
# Log entries older than DATEREFERENCE will not be considered.
DATEREFERENCE=$(date --date="-${TIMEPERIOD} minutes" +"%Y-%m-%d-%H:%M:%S")
printVerbose "Time period reference: ${DATEREFERENCE}"

# Check if there is a log ftreceptor to analize from today or yesterday, and get the error count:
if [[ -r "${DIRNAME}/ftreceptor${DATETODAY}.log" ]]; then
  ERRORSRECEPTOR=$(grep "${ERRORSTR}" "${DIRNAME}/ftreceptor${DATETODAY}.log" | awk -v dateref=${DATEREFERENCE} 'BEGIN{sum = 0;}{$1 = substr($1, 8, 4) "-" substr($1, 5, 2) "-" substr($1, 2, 2) "-" substr($2, 1, 8); }{ if ($1 >= dateref) {sum = sum + 1;} }END{print sum;}')
  printVerbose "Log ftreceptor from today found"
else
  if [[ -r "${DIRNAME}/ftreceptor${DATEYESTERDAY}.log" ]]; then
    ERRORSRECEPTOR=$(grep "${ERRORSTR}" "${DIRNAME}/ftreceptor${DATEYESTERDAY}.log" | awk -v dateref=${DATEREFERENCE} 'BEGIN{sum = 0;}{$1 = substr($1, 8, 4) "-" substr($1, 5, 2) "-" substr($1, 2, 2) "-" substr($2, 1, 8); }{ if ($1 >= dateref) {sum = sum + 1;} }END{print sum;}')
    printVerbose "Log ftreceptor from yesterday found"
  fi
fi
printVerbose "Errors receptor: ${ERRORSRECEPTOR}"

# Check if there is a log ftenviador to analize from today or yesterday, and get the error count:
if [[ -r "${DIRNAME}/ftenviador${DATETODAY}.log" ]]; then
  ERRORSENVIADOR=$(grep "${ERRORSTR}" "${DIRNAME}/ftenviador${DATETODAY}.log" | awk -v dateref=${DATEREFERENCE} 'BEGIN{sum = 0;}{$1 = substr($1, 8, 4) "-" substr($1, 5, 2) "-" substr($1, 2, 2) "-" substr($2, 1, 8); }{ if ($1 >= dateref) {sum = sum + 1;} }END{print sum;}')
  printVerbose "Log ftenviador from today found"
else
  if [[ -r "${DIRNAME}/ftenviador${DATEYESTERDAY}.log" ]]; then
    ERRORSENVIADOR=$(grep "${ERRORSTR}" "${DIRNAME}/ftenviador${DATEYESTERDAY}.log" | awk -v dateref=${DATEREFERENCE} 'BEGIN{sum = 0;}{$1 = substr($1, 8, 4) "-" substr($1, 5, 2) "-" substr($1, 2, 2) "-" substr($2, 1, 8); }{ if ($1 >= dateref) {sum = sum + 1;} }END{print sum;}')
    printVerbose "Log ftenviador from yesterday found"
  fi
fi
printVerbose "Errors enviador: ${ERRORSENVIADOR}"

# Performance metric:
PERFORMANCE="errors_receptor=${ERRORSRECEPTOR};1;${CRITCOUNT} errors_enviador=${ERRORSENVIADOR};1;${CRITCOUNT}"

# Report:
RESULTMSG="OK - No errors found in ${DIRNAME} in the last ${TIMEPERIOD} minutes | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${ERRORSRECEPTOR} -gt ${CRITCOUNT} ]] || [[ ${ERRORSENVIADOR} -gt ${CRITCOUNT} ]]; then
  RESULTMSG="CRITICAL - ${ERRORSRECEPTOR} errors found in ftreceptor and ${ERRORSENVIADOR} errors found in ftenviador in the last ${TIMEPERIOD} minutes | ${PERFORMANCE}"
  RESULTCODE=${STATE_CRITICAL}
else
  if [[ ${ERRORSRECEPTOR} -gt 0 ]] || [[ ${ERRORSENVIADOR} -gt 0 ]]; then
    RESULTMSG="WARNING - ${ERRORSRECEPTOR} errors found in ftreceptor and ${ERRORSENVIADOR} errors found in ftenviador in the last ${TIMEPERIOD} minutes | ${PERFORMANCE}"
    RESULTCODE=${STATE_WARNING}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


