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
  echo "Description: Monitoring plugin to check mount points."
  echo ""
  echo "Usage: ${PROGNAME} [--verbose-mode] | [-V | -h] <COMPLETAR>"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  --verbose-mode  Optional. Turn on verbose mode"
  echo ""
  echo "Example: ${PROGNAME}"
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
# Perform checks
#

# Get configured mount points:
MOUNTPOINTS=$(grep -v "^#" /etc/fstab | awk '{if ($3 != "rootfs" && $3 != "swap" && $3 != "ext4" && $3 != "ext3" && $3 != "tmpfs" && $3 != "devpts" && $3 != "sysfs" && $3 != "proc") print $2;}')
printVerbose "MOUNT POINTS: ${MOUNTPOINTS}"
CRITERROR=0
WARNERROR=0
MPCRIT=""
MPWARN=""
for mp in ${MOUNTPOINTS}; do
  # For each mp, check if it is mounted:
  ISMOUNTED=$(mount | sed "s/^.* on \(.*\) type .*$/\1/g" | grep "${mp}" | wc -l)
  printVerbose "IS MOUNTED: ${mp} --> ${ISMOUNTED}"
  if [[ ${ISMOUNTED} -eq 0 ]]; then
    CRITERROR=1
    if [[ ${MPCRIT} == "" ]]; then
      MPCRIT="${mp}"
    else
      MPCRIT="${MPCRIT}, ${mp}"
    fi
  else
    # For each mp, check if it is not in read only mode:
    ISRW=$(grep "${mp}" /proc/mounts | awk '{print $4;}' | sed "s/,/ /g" | awk 'BEGIN{sum=0;}{for(i=1; i<=NF; i++){ if($i == "rw") sum=sum+1;}}END{print sum;}')
    printVerbose "IS RW: ${mp} --> ${ISRW}"
    if [[ ${ISRW} -eq 0 ]]; then
      WARNERROR=1
      if [[ ${MPWARN} == "" ]]; then
        MPWARN="${mp}"
      else
        MPWARN="${MPWARN}, ${mp}"
      fi
    fi
  fi
done
# Performance metric:
ERRORS=$((${CRITERROR} + ${WARNERROR}))
PERFORMANCE="errors=${ERRORS}"

# Report:
if [[ ${CRITERROR} -gt 0 ]]; then
  RESULTMSG="CRITICAL - Los siguientes puntos de montaje no se encuentran activos: ${MPCRIT} | ${PERFORMANCE}"
  RESULTCODE=${STATE_CRITICAL}
else
  if [[ ${WARNERROR} -gt 0 ]]; then
    RESULTMSG="WARNING - Los siguientes puntos de montaje están en modo READ ONLY: ${MPWARN} | ${PERFORMANCE}"
    RESULTCODE=${STATE_WARNING}
  else
    RESULTMSG="OK - Todos los puntos de montaje definidos están montados y en modo READ WRITE | ${PERFORMANCE}"
    RESULTCODE=${STATE_OK}
  fi
fi

echo "${RESULTMSG}"
exit ${RESULTCODE}


