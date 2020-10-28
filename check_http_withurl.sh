#!/bin/bash
#
# Plugin para monitorizar una url e informarla como parte del status
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_http_withurl.sh -P /usr/lib64/nagios/plugins -H as1.test.prodalam.b2b -p 8080 -u BBR2-commerce
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
  echo "Description: Plugin para monitorizar una url e informarla como parte del status."
  echo ""
  echo "Usage: ${PROGNAME} -P <nagios_plugins_path> <same parameters as check_http> | -h | -V"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -P              Nagios Plugins path. MUST be the first parameter"
  echo "  *               Same parameters as check_http"
  echo ""
  echo "Example: ${PROGNAME} -P /usr/lib64/nagios/plugins -H as1.test.prodalam.b2b -p 8080 -u BBR2-commerce"
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
# Grab the command line arguments
case "$1" in
  -h)
    print_usage
    exit ${STATE_OK}
    ;;
  -V)
    print_version
    exit ${STATE_OK}
    ;;
  -P)
    shift
    PLUGINSPATH=$1
    ;;
  *)
    echo "Unknown argument: $1. First parameter must be one of: -h, -V or -P"
    print_usage
    exit ${STATE_UNKNOWN}
    ;;
esac

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for mandatory parameters
#
if [[ -z ${PLUGINSPATH} ]]; then
  echo "UNKNOWN - Missing parameters"
  print_usage
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if check_http is available
#
if [[ -x "${PLUGINSPATH}/check_http" ]]; then
  echo "UNKNOWN - check_http plugin not found or not executable in this path: ${PLUGINSPATH}"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform check
#
RESULT=$(${PLUGINSPATH}/check_http $@)
RETCODE=$?

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


