#!/bin/bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check Dual TCP Plugin
#
# Version: 1.0
# Author: BBR SpA
# Support: soporte@bbr.cl
#
# Example usage:
#
#   ./check_tcp2.sh -H1 IP1 -P1 Port1 -H2 IP2 -P2 Port2
#
# Requirements: this plugin require tcping installed.
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
AUTHOR="BBR SpA"
VERSION="1.0"
PROGNAME=$(basename $0)

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
  echo "Usage: $PROGNAME [ -H1 IP1 -P1 Port1 -H2 IP2 -P2 Port2 ] | [-v | -h]"
  echo ""
  echo "  -h  Show this page"
  echo "  -v  Plugin Version"
  echo "  -H1 First IP address"
  echo "  -P1 First port number"
  echo "  -H2 Second IP address"
  echo "  -P2 Second port number"
  echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 1 ]; then
  echo "Insufficient arguments"
  print_usage
  exit $STATE_UNKNOWN
fi
# Grab the command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h)
      print_usage
      exit $STATE_OK
      ;;
    -v)
      print_version
      exit $STATE_OK
      ;;
    -H1)
      shift
      HOSTADDR1=$1
      ;;
    -P1)
      shift
      HOSTPORT1=$1
      ;;
    -H2)
      shift
      HOSTADDR2=$1
      ;;
    -P2)
      shift
      HOSTPORT2=$1
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
if [[ -z ${HOSTADDR1} ]] || [[ -z ${HOSTPORT1} ]] || [[ -z ${HOSTADDR2} ]] || [[ -z ${HOSTPORT2} ]]; then
  echo "UNKNOWN - Missing parameters"
  print_usage
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check tcping for each address and port
#
PSTATUS1=$(tcping -t 4 ${HOSTADDR1} ${HOSTPORT1})
RC1=$(echo $?)
if [[ ${RC1} -ne 0 ]]; then
  RC1=1
fi
PSTATUS2=$(tcping -t 4 ${HOSTADDR2} ${HOSTPORT2})
RC2=$(echo $?)
if [[ ${RC2} -ne 0 ]]; then
  RC2=1
fi
RESULT=$((${RC1} * 2 + ${RC2}))
case ${RESULT} in
  0)
    FINAL_STATUS="OK - Both address responding"
    RETURN_STATUS=$STATE_OK
    ;;
  1)
    FINAL_STATUS="OK - ${HOSTADDR2} not responding on port ${HOSTPORT2}"
    RETURN_STATUS=$STATE_OK
    ;;
  2)
    FINAL_STATUS="OK - ${HOSTADDR1} not responding on port ${HOSTPORT1}"
    RETURN_STATUS=$STATE_OK
    ;;
  3)
    FINAL_STATUS="WARNING - ${HOSTADDR1} on port ${HOSTPORT1} and ${HOSTADDR2} on port ${HOSTPORT2} not responding"
    RETURN_STATUS=$STATE_WARNING
    ;;
esac

# Performance metric:
ERRORS=$((${RC1} + ${RC2}))
PERFORMANCE="errors=${ERRORS}"

echo "$FINAL_STATUS | ${PERFORMANCE}"
exit $RETURN_STATUS

