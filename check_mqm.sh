#!/bin/bash
#
# Check for mqm long time queued messages
#
# Author: BBR
# Contact: soporte@bbr.cl
#
# Requirements: nagios user must be added to mqm group
#
# Example usage:
#   /usr/local/nagios/libexec/check_mqm.sh -Q QMGR -w 30 -c 60
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
VERSION="1.2"
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
  echo ""
  echo "Usage: ${PROGNAME} -w <warning_time> -c <critical_time> [-e 'list_of_excluded_queues'] | [-V | -h]"
  echo ""
  echo "  -h          Show this page"
  echo "  -V          Plugin Version"
  echo "  -Q [QMGR]   Queue Manager"
  echo "  -w [TIME]   Warning time in seconds allowed for a message to be queued"
  echo "  -c [TIME]   Critical time in seconds allowed for a message to be queued"
  echo "  -e [QLIST]  List of queues excluded"
  echo ""
  echo "Example: ${PROGNAME} -w 300 -c 600"
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
    -Q)
      shift
      QMGR=$1
      ;;
    -w)
      shift
      WARNTIME=$1
      ;;
    -c)
      shift
      CRITTIME=$1
      ;;
    -e)
      shift
      EXCLUDEDQUEUES=$1
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
if [[ -z ${QMGR} ]] || [[ -z ${WARNTIME} ]] || [[ -z ${CRITTIME} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if MONQ parameter is HIGH
#
MONQ=$(echo "display QMGR MONQ" |runmqsc ${QMGR} |grep "MONQ(.*)" |sed "s/^.*MONQ(//g" |cut -d ")" -f1)
if [[ -z ${MONQ} ]] || [[ ${MONQ} -ne "HIGH" ]]; then
  echo "UNKNOWN - MONQ parameter should be HIGH. RUN: ALTER QMGR MONQ(HIGH)"
  exit ${STATE_UNKNOWN}
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

### REMOVED in 1.2 since QMGR is passed by in parameter -Q
# Get managers on the server:
#QMNAMES=$(dspmq |cut -d '(' -f2 |cut -d ')' -f1)

# Check variables:
LATEQUEUES=""
HIGHERERROR=0
PERFORMANCE=""

### REMOVED in 1.2 since QMGR is passed by in parameter -Q
# Iterate over managers:
#for qmanager in ${QMNAMES}
#do

# Get queue list for this manager:
QUEUELIST=$(echo "display qstatus(*) TYPE(QUEUE)" |runmqsc ${QMGR} |grep "QUEUE(.*)*TYPE(QUEUE)" |cut -d "(" -f2 |cut -d ")" -f1 |grep -v "^SYSTEM.")

# Iterate over queues:"
for queue in ${QUEUELIST}
do
  # Check if this queue is not excluded:
  EXCLUDED=0
  for exqueue in ${EXCLUDEDQUEUES}
  do
    if [[ ${exqueue} == ${queue} ]]; then
      EXCLUDED=1
    fi
  done
  if [[ ${EXCLUDED} -eq 1 ]]; then
    continue
  fi

  # Get age of the oldest message in queue:
  MSGAGE=$(echo "display qstatus(${queue}) MSGAGE" |runmqsc ${QMGR} |grep "MSGAGE(.*)" |sed 's/.*MSGAGE(//g' |cut -d ")" -f1)
    
  # If it is not empty:
  if [[ ${MSGAGE} -ne " " ]]; then
    # If it is greather than warning value:
    if [[ ${MSGAGE} -gt ${WARNTIME} ]]; then
      # If there is not a higher error:
      if [[ ${HIGHERERROR} -lt 2 ]]; then
        HIGHERERROR=1
      fi
      # If it is greather than critical value:
      if [[ ${MSGAGE} -gt ${CRITTIME} ]]; then
        HIGHERERROR=2
      fi
      # Add manager and queue to late queues list:
      if [[ ${LATEQUEUES} ]]; then
        LATEQUEUES="$LATEQUEUES, ${queue}"
      else
        LATEQUEUES="${queue}"
      fi
    fi
  else
    # If there is no value, assume 0:
    MSGAGE=0
  fi # MSGAGE
  
  # Record performance metrics:
  if [[ ${PERFORMANCE} ]]; then
    PERFORMANCE="${PERFORMANCE} ${queue}=${MSGAGE}s;${WARNTIME};${CRITTIME}"
  else
    PERFORMANCE="${queue}=${MSGAGE}s;${WARNTIME};${CRITTIME}"
  fi
    
done #QUEUELIST

#done # QMNAMES

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Report results
#
if [[ ${HIGHERERROR} -eq 0 ]]; then
  echo "OK - No se encontraron mensajes encolados por mas de ${WARNTIME} segundos | ${PERFORMANCE}"
  exit ${STATE_OK}
elif [[ ${HIGHERERROR} -eq 1 ]]; then
  echo "WARNING - Las siguientes colas tinen mensajes pendientes por mas de ${WARNTIME} segundos: ${LATEQUEUES} | ${PERFORMANCE}"
  exit ${STATE_WARNING}
else
  echo "CRITICAL - Las siguientes colas tinen mensajes pendientes por mas de ${WARNTIME} o ${CRITTIME} segundos: ${LATEQUEUES} | ${PERFORMANCE}"
  exit ${STATE_CRITICAL}
fi

