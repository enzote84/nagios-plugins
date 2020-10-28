#!/bin/bash
#
# This plugin monitors all the docker images in a server
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Example usage:
#   /usr/lib64/nagios/plugins/check_docker.sh -e '53e80e53be80 4137e8e25537'
#
### Important: nrpe user must be in docker group in order to run docker commands ###
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
  echo "Description: This plugin monitors all the docker images in a server."
  echo ""
  echo "Usage: ${PROGNAME} [-e <id exclude list>] [--verbose-mode] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -e [LIST]       Optional. List of the containers' ID to exclude"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME} -e '53e80e53be80 4137e8e25537'"
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
    -e)
      shift
      EXCLUDELIST=$1
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
#if [[ -z ${WARNMEM} ]] || [[ -z ${CRITMEM} ]]; then
#  echo "UNKNOWN - Missing parameters"
#  exit ${STATE_UNKNOWN}
#fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
# Get all the containers with problems:
#DCKRLIST=$(docker ps -a -f "status=dead" -f "status=exited" --format "{{.Names}},{{.Status}}")
DCKRLIST=$(docker ps -a -f "status=dead" -f "status=exited" --format "{{.ID}}")
DCKRSVC=$?
if [[ ${DCKRSVC} -ne 0 ]]; then
  RESULTMSG="UNKNOWN - Couldn't connect to Docker. Maybe Docker service is not running."
  RESULTCODE=${STATE_UNKNOWN}
else
  printVerbose "Docker id list: ${DCKRLIST}"
  # First asume that there are no errors:
  RESULTMSG="OK - There are no Docker containers in error state."
  RESULTCODE=${STATE_OK}
  if [[ ${DCKRLIST} != "" ]]; then
    ERRORDOCKS=""
    # Iterate over each container with error status:
    for container in ${DCKRLIST}
    do
      # Check if this container is not excluded:
      EXCLUDED=0
      for excont in ${EXCLUDELIST}
      do
        if [[ ${excont} == ${container} ]]; then
          EXCLUDED=1
        fi
      done
      if [[ ${EXCLUDED} -eq 1 ]]; then
        printVerbose "Container ${container} excluded"
        continue
      fi
      # Get container status information:
      DCKRNAME=$(docker ps -a -f "id=${container}" --format "{{.Names}}")
      printVerbose "${container} name: ${DCKRNAME}"
      DCKRSTATUS=$(docker ps -a -f "id=${container}" --format "{{.Status}}")
      printVerbose "${container} status: ${DCKRSTATUS}"
      DCKRCODE=$(echo ${DCKRSTATUS} | sed "s/.*(\(.*\)).*/\1/g")
      printVerbose "${container} code: ${DCKRCODE}"
      # Report errors only if exit code if different than 0:
      if [[ ${DCKRCODE} -ne 0 ]]; then
        if [[ ${ERRORDOCKS} == "" ]]; then
          ERRORDOCKS="${DCKRNAME} -> ${DCKRSTATUS}"
        else
          ERRORDOCKS="${ERRORDOCKS}, ${DCKRNAME} -> ${DCKRSTATUS}"
        fi
      fi
    done
    printVerbose "ERRORDOCKS: ${ERRORDOCKS}"
    if [[ ${ERRORDOCKS} != "" ]]; then
      RESULTMSG="CRITICAL - The following containers are in an error state: ${ERRORDOCKS}."
      RESULTCODE=${STATE_CRITICAL}
    fi
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}

