#!/bin/bash
#
# Check free memory
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/local/nagios/libexec/check_free.sh -w 10 -c 5
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
  echo "Description: Checks free memory available on the system."
  echo ""
  echo "Usage: ${PROGNAME} -w <free % warning> -c <free % critical> | [-V | -h]"
  echo ""
  echo "  -h          Show this page"
  echo "  -V          Plugin Version"
  echo "  -w [VALUE]   Warning free memory value in %"
  echo "  -c [VALUE]   Critical free memory value in %"
  echo ""
  echo "Example: ${PROGNAME} -w 10 -c 5"
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
    -w)
      shift
      WARNMEM=$1
      ;;
    -c)
      shift
      CRITMEM=$1
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
# Check free memory
#
TOTALMEM=$(free -m | grep "Mem:" | awk '{print $2;}')
USEDMEM=$(free -m | grep "Mem:" | awk '{print $3;}')
USEDWARN=$(echo "${TOTALMEM} * (100 - ${WARNMEM}) / 100" | bc)
USEDCRIT=$(echo "${TOTALMEM} * (100 - ${CRITMEM}) / 100" | bc)
FREEPCT=$(free -m | grep "Mem:" | awk '{print int($4/$2*100);}')

# Performance metric:
PERFORMANCE="free_pct=${FREEPCT}%;${WARNMEM};${CRITMEM} usage=${USEDMEM}MB;${USEDWARN};${USEDCRIT};0;${TOTALMEM}"

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


