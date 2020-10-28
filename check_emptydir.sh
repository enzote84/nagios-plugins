#!/bin/bash
#
# Check if a directory is empty or does not have files older than 1 hour
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_emptydir.sh -D /tmp/cache -c 10
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
VERSION="2.0"
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
  echo "Description: <COMPLETAR>."
  echo ""
  echo "Usage: ${PROGNAME} -D <directory path> [-t <max age minutes>] [-c <number of files for critical>] | [-V | -h]"
  echo ""
  echo "  -h          Show this page"
  echo "  -V          Plugin Version"
  echo "  -D [PATH]   Directory full path"
  echo "  -t [VALUE]  Max file age in minutes. Alert if a file is older than VALUE. Default: 60 minutes."
  echo "  -c [VALUE]  Number of files for a critical condition"
  echo ""
  echo "Example: ${PROGNAME} -D /var/log/errors -c 5"
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
# Default parameters:
CRITFILES=10
MAXAGE=60
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
    -D)
      shift
      DIRPATH=$1
      ;;
    -t)
      shift
      MAXAGE=$1
      ;;
    -c)
      shift
      CRITFILES=$1
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
if [[ -z ${DIRPATH} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if directory exists and it is accessible
#
if [[ ! -d ${DIRPATH} ]]; then
  echo "UNKNOWN - Directory ${DIRPATH} does not exist"
  exit ${STATE_UNKNOWN}
fi

if [[ ! -r ${DIRPATH} ]] || [[ ! -x ${DIRPATH} ]]; then
  echo "UNKNOWN - Directory ${DIRPATH} is not accessible"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
NUMFILES=$(find ${DIRPATH} -type f -mmin +${MAXAGE} | wc -l)

# Performance metric:
PERFORMANCE="numfiles=${NUMFILES};0;${CRITFILES}"

# Report:
TEXT="Directory ${DIRPATH} has ${NUMFILES} files"
RESULTMSG="OK - ${TEXT} | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${NUMFILES} -gt 0 ]]; then
  RESULTMSG="WARNING - ${TEXT} | ${PERFORMANCE}"
  RESULTCODE=${STATE_WARNING}
  if [[ ${NUMFILES} -gt ${CRITFILES} ]]; then
    RESULTMSG="CRITICAL - ${TEXT} | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


