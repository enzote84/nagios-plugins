#!/bin/bash
#
# Check if a file is present in a directory
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_fileindir.sh -D /tmp/cache -F "^MYFILE-*.txt" -M 600
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
  echo "Description: <COMPLETAR>."
  echo ""
  echo "Usage: ${PROGNAME} -D <directory path> -F <file name pattern> [-M <modified minutes>] [--critical] | [-V | -h]"
  echo ""
  echo "  -h           Show this page"
  echo "  -V           Plugin Version"
  echo "  -D [PATH]    Directory full path"
  echo "  -F [NAME]    File name pattern to match"
  echo "  -M [MINUTES] Optional. Minutes from the files's 'last modification time"
  echo "  --critical   Optional. Return critical instead of Warning if file is not found"
  echo ""
  echo "Example: ${PROGNAME} -D /tmp/cache -F \"^MYFILE-*.txt\" -M 600"
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
CRITICAL=0
MINUTESAGO=0
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
    -F)
      shift
      FILEPATTERN=$1
      ;;
    -M)
      shift
      MINUTESAGO=$1
      ;;
    --critical)
      CRITICAL=1
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
if [[ -z ${DIRPATH} ]] || [[ -z ${FILEPATTERN} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if directory exists
#
if [[ ! -d ${DIRPATH} ]]; then
  echo "UNKNOWN - Directory ${DIRPATH} does not exist"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
if [[ ${MINUTESAGO} -eq 0 ]]; then
  NUMFILES=$(find ${DIRPATH} -name "${FILEPATTERN}" | wc -l)
else
  NUMFILES=$(find ${DIRPATH} -name "${FILEPATTERN}" -mmin -${MINUTESAGO} | wc -l)
fi

# Performance metric:
PERFORMANCE="numfiles=${NUMFILES};0;0"

# Report:
TEXT="Directory ${DIRPATH} has ${NUMFILES} files matching the pattern: ${FILEPATTERN}"
RESULTMSG="OK - ${TEXT} | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${NUMFILES} -eq 0 ]]; then
  RESULTMSG="WARNING - ${TEXT} | ${PERFORMANCE}"
  RESULTCODE=${STATE_WARNING}
  if [[ ${CRITICAL} -eq 1 ]]; then
    RESULTMSG="CRITICAL - ${TEXT} | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


