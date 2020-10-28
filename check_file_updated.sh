#!/bin/bash
#
# Script para monitorear que un archivo X se haya actualizado en los últimos N minutos.
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_file_updated.sh -w 1440 -c 1800 -f /opt/file.txt
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
  echo "Description: Script para monitorear que un archivo X se haya actualizado en los últimos N minutos."
  echo ""
  echo "Usage: ${PROGNAME} -f <file_path> [-w <warning minutes>] [-c <critical minutes>] [--verbose-mode] | [-V | -h] <COMPLETAR>"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -f              Path of the file to monitor"
  echo "  -w [VALUE]      Optional. Modified warning minutes. Default 1440 (24 hours)"
  echo "  -c [VALUE]      Optional. Modified critical minutes. Default 1800 (30 hours)"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME} -w 10 -c 25 -f /opt/file.txt"
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
WARNMINUTES=1440
CRITMINUTES=1800
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
    -f)
      shift
      FILEPATH=$1
      ;;
    -w)
      shift
      WARNMINUTES=$1
      ;;
    -c)
      shift
      CRITMINUTES=$1
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
if [[ -z ${FILEPATH} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

# Check if file exists:
if [[ ! -s ${FILEPATH} ]]; then
  echo "UNKNOWN - File ${FILEPATH} does not exists!"
  exit ${STATE_UNKNOWN}
fi

# Get current time and file's modification time:
CURRENTTIME=$(date +%s)
FILESMODTIME=$(ls -l --time-style=+%s ${FILEPATH} | cut -f6 -d' ')
printVerbose "CURRENTTIME: ${CURRENTTIME}"
printVerbose "FILESMODTIME: ${FILESMODTIME}"
# Calculate difference in minutes:
DIFFMINUTES=$(((${CURRENTTIME} - ${FILESMODTIME}) / 60))
printVerbose "DIFFMINUTES: ${DIFFMINUTES}"

# Performance metric:
PERFORMANCE="time=${DIFFMINUTES}m;${WARNMINUTES};${CRITMINUTES}"

# Check if file was modified before WARNING and CRITICAL levels:
if [[ ${DIFFMINUTES} -lt ${WARNMINUTES} ]]; then
  RESULTMSG="OK - The file ${FILEPATH} was modified ${DIFFMINUTES} minutes ago. | ${PERFORMANCE}"
  RESULTCODE=${STATE_OK}
else
  if [[ ${DIFFMINUTES} -lt ${CRITMINUTES} ]]; then
    RESULTMSG="WARNING - The file ${FILEPATH} was modified ${DIFFMINUTES} minutes ago and is over the ${WARNMINUTES} minutes threshlod. | ${PERFORMANCE}"
    RESULTCODE=${STATE_WARNING}
  else
    RESULTMSG="CRITICAL - The file ${FILEPATH} was modified ${DIFFMINUTES} minutes ago and is over the ${CRITMINUTES} minutes threshlod. | ${PERFORMANCE}"
    RESULTCODE=${STATE_WARNING}
  fi
fi

# Report:
echo "${RESULTMSG}"
exit ${RESULTCODE}


