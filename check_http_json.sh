#!/bin/bash
#
# check_http_json.sh
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_http_json.sh -I 10.200.100.10 -u /api -p 8080 -k "value" -v "1.0"
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
  echo "Description: This plugins connects to an URL and verifies the value of a key in a json result."
  echo ""
  echo "Usage: ${PROGNAME} -I <host ip> [-u <uri>] [-p <port>] -k <key label> -v <value to check> [--critical] [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -I [IP]         Host IP or FQDN to check"
  echo "  -u [STRING]     Optional. URI to get on the server. Deafult: /"
  echo "  -p [VALUE]      Optional. Port number to check. Default: 80"
  echo "  -k [STRING]     Label of the key to check"
  echo "  -v [STRING]     String of the value to check"
  echo "  --critical      Optional. Report a critical alert instead of warning"
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
CRITICAL=0
HOSTURI="/"
HOSTPORT="80"
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
    -I)
      shift
      HOSTIP=$1
      ;;
    -p)
      shift
      HOSTPORT=$1
      ;;
    -u)
      shift
      HOSTURI=$1
      ;;
    -k)
      shift
      JSONKEY=$1
      ;;
    -v)
      shift
      JSONVALUE=$1
      ;;
    --critical)
      CRITICAL=1
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
if [[ -z ${HOSTIP} ]] || [[ -z ${JSONKEY} ]] || [[ -z ${JSONVALUE} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
URL="http://${HOSTIP}:${HOSTPORT}${HOSTURI}"
printVerbose "URL: ${URL}"
printVerbose "Key seeked: ${JSONKEY}"
printVerbose "Value seeked: ${JSONVALUE}"
RESPONSE=$(curl --silent --get --connect-timeout 4 --url ${URL})
if [[ $? -ne 0 ]]; then
  echo "UNKNOWN - Server ${HOSTIP} is not responding"
  exit ${STATE_UNKNOWN}
fi
printVerbose "Response: ${RESPONSE}"
RESULT=$(echo ${RESPONSE} | grep -Po ".${JSONKEY}.:.*," | cut -f1 -d',' | cut -f2 -d':' | grep "${JSONVALUE}" | wc -l)
printVerbose "Result: ${RESULT}"

# Performance metric:
PERFORMANCE="value=${RESULT}"

# Report:
RESULTMSG="OK - URL status is ${RESULT} | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${RESULT} -ne 1 ]]; then
  RESULTMSG="WARNING - URL status is ${RESULT} | ${PERFORMANCE}"
  RESULTCODE=${STATE_WARNING}
  if [[ ${CRITICAL} -ne 0 ]]; then
    RESULTMSG="CRITICAL - URL status is ${RESULT} | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


