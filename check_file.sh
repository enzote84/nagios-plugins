#!/bin/bash
#
# Este plugin revisa que la cantidad de archivos en un directorio sea menor al umbral
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_file.sh -w 5 -c 10 -d /tmp
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
  echo "Description: Este plugin revisa que la cantidad de archivos en un directorio sea menor al umbral."
  echo ""
  echo "Usage: ${PROGNAME} -w <num_files> -c <num_files> -d <dir_path> [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -w [VALUE]      Warning number of files"
  echo "  -c [VALUE]      Critical number of files"
  echo "  -d [STRING]     Directory path to check"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME} -w 5 -c 10 -d /tmp"
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
      WARNFILES=$1
      ;;
    -c)
      shift
      CRITFILES=$1
      ;;
    -d)
      shift
      DIRPATH=$1
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
if [[ -z ${WARNFILES} ]] || [[ -z ${CRITFILES} ]] || [[ -z ${DIRPATH} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if directory is accesible and readable
#
if [[ ! -r ${DIRPATH} ]]; then
  echo "UNKNOWN - ${DIRPATH} cannot be read"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
QUERY=$(ls ${DIRPATH} | wc -l)

# Performance metric:
PERFORMANCE="numfiles=${QUERY};${WARNFILES};${CRITFILES}"

# Report:
RESULTMSG="OK - La cantidad de archivos en el directorio ${DIRPATH} es ${QUERY} | ${PERFORMANCE}"
RESULTCODE=${STATE_OK}
if [[ ${QUERY} -gt ${WARNFILES} ]]; then
  RESULTMSG="WARNING - La cantidad de archivos en el directorio ${DIRPATH} es ${QUERY} | ${PERFORMANCE}"
  RESULTCODE=${STATE_WARNING}
  if [[ ${QUERY} -gt ${CRITFILES} ]]; then
    RESULTMSG="CRITICAL - La cantidad de archivos en el directorio ${DIRPATH} es ${QUERY} | ${PERFORMANCE}"
    RESULTCODE=${STATE_CRITICAL}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


