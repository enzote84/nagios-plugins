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
  echo "Description: <COMPLETAR>."
  echo ""
  echo "Usage: ${PROGNAME} -w <free % warning> -c <free % critical> [--verbose-mode] | [-V | -h] <COMPLETAR>"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -w [VALUE]      Warning free memory value in %"
  echo "  -c [VALUE]      Critical free memory value in %"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME} -w 10 -c 5 <COMPLETAR>"
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
    -w)
      shift
      WARNMEM=$1
      ;;
    -c)
      shift
      CRITMEM=$1
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
if [[ -z ${WARNMEM} ]] || [[ -z ${CRITMEM} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks <COMPLETAR>
#


# Performance metric:
PERFORMANCE="metric1=${METRIC1}%;${WARNMEM};${CRITMEM} metric2=${METRIC2}MB;${USEDWARN};${USEDCRIT};0;${TOTALMEM}"

# Report:
RESULTMSG="OK - Free memory is ${FREEPCT}% | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${FREEPCT} -lt ${WARNMEM} ]]; then
  RESULTMSG="WARNING - Free memory is ${FREEPCT}% | ${PERFORMANCE}"
  RESULTCODE=${STATE_WARNING}
  if [[ ${FREEPCT} -lt ${CRITMEM} ]]; then
    RESULTMSG="CRITICAL - Free memory is ${FREEPCT}% | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


