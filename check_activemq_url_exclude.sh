#!/bin/bash
#
# Nagios script to check queued messages on ActiveMQ
#
# Version: 1.0
# Author: BBR
# Support: soporte@bbr.cl
#
# Example usage:
#   ./check_activemq.sh -w 300 -c 600
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
AUTHOR="BBR"
VERSION="1.0"
PROGNAME=$(basename $0)
BASEDIR=$(dirname $0)

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
  echo "Usage: $PROGNAME [-H <ip|fqdn> -w <warning_time> -c <critical_time> [-u 'user:passwd'] [-e 'list_of_excluded_queues'] [--verbose-mode] ] | [-V | -h]"
  echo ""
  echo "  -h              Show this page"
  echo "  -V              Plugin Version"
  echo "  -H              IP or fqdn of ActiveMQ host"
  echo "  -w              Maximum time in seconds of the oldest message for a warning"
  echo "  -c              Maximum time in seconds of the oldest message for a critical"
  echo "  -u              Optional. User authentication: user:passwd. Default: admin:admin"
  echo "  -e              Opcional. List of excluded queues"
  echo "  --verbose-mode  Optional. Verbose output"
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
  exit $STATE_UNKNOWN
fi
# Defaults:
USERPASSWD="admin:admin"
VERBOSE=0
# Grab the command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h)
      print_usage
      exit $STATE_OK
      ;;
    -V)
      print_version
      exit $STATE_OK
      ;;
    -H)
      shift
      HOSTIP=$1
      ;;
    -w)
      shift
      WARNTIME=$1
      ;;
    -c)
      shift
      CRITTIME=$1
      ;;
    -u)
      shift
      USERPASSWD=$1
      ;;
    -e)
      shift
      EXCLUDEDQUEUES=$1
      ;;
    --verbose-mode)
      VERBOSE=1
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
if [[ -z ${HOSTIP} ]] || [[ -z ${WARNTIME} ]] || [[ -z ${CRITTIME} ]]; then
  echo "UNKNOWN - Missing parameters"
  exit ${STATE_UNKNOWN}
fi
printVerbose "Host:     ${HOSTIP}"
printVerbose "Warning:  ${WARNTIME}"
printVerbose "Critical: ${CRITTIME}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Commands and variables
#

# Current timestamp:
CURTIMESTMP=$(date +%s)
printVerbose "Timestmp: ${CURTIMESTMP}"
# Check variables:
LATEQUEUES=""
HIGHERERROR=0
PERFORMANCE=""
# Curl:
TIMEOUT=4
CURLFMT="/tmp/check_activemq_curl_format_$$.txt"
echo "%{time_total}\n" > ${CURLFMT}
# Errors:
ERRORS="/tmp/check_activemq_errors_$$.tmp"
# Queues:
OUTFILE="/tmp/check_activemq_$$.tmp"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

# Check connection to URL:
RESPONSETIME=$(curl -w "@${CURLFMT}" --connect-timeout "${TIMEOUT}" -o /dev/null -s "http://${HOSTIP}:8161/admin/queues.jsp")
printVerbose "Response time: ${RESPONSETIME}"
RESPONSETIME=$(echo "${RESPONSETIME}" | cut -d',' -f1)
# Delete curl format:
rm ${CURLFMT}
# Check response time:
if [[ ${RESPONSETIME} -ge ${TIMEOUT} ]]; then
  echo "UNKNOWN - Host ${HOSTIP} no responde"
  exit ${STATE_UNKNOWN}
fi

# Get Queues:
curl -s --get --output "${OUTFILE}" --connect-timeout "${TIMEOUT}" --user "${USERPASSWD}" --url "http://${HOSTIP}:8161/admin/queues.jsp;jsessionid=khqt6seluuouls9o88zr3ppz"
if [[ ! -s "${OUTFILE}" ]]; then
  echo "OK - ActiveMQ en modo esclavo"
  exit ${STATE_OK}
fi
# Queue list:
QUEUELIST=$(sed -n '/<table.*id="queues".*>/,/<\/table>/p' "${OUTFILE}" | sed 's/^[\ \t]*//g' | tr -d '\n' | sed 's/<\/TR[^>]*>/\n/Ig'  | sed 's/<\/\?\(TABLE\|TBODY\|TR\|TH\|A\)[^>]*>//Ig' | sed 's/^<T[DH][^>]*>\|<\/\?T[DH][^>]*>$//Ig' | sed 's/<\/T[DH][^>]*><T[DH][^>]*>/,/Ig' | grep -v "Name" | cut -d',' -f1,2,3)
# Output is: QUEUE NAME,#MESSAGES,#CONSUMERS
printVerbose "Queue List:"
printVerbose "Name,#Messages,#Consumers"
printVerbose "${QUEUELIST}"
rm ${OUTFILE}

# Check Messages in Queue:
for queue in ${QUEUELIST}
do

  QUEUENAME=$(echo ${queue} | cut -d',' -f1)
  QUEUESIZE=$(echo ${queue} | cut -d',' -f2)
  QUEUECONS=$(echo ${queue} | cut -d',' -f3)
  PERFORMANCE="${PERFORMANCE} ${QUEUENAME}_size=${QUEUESIZE} ${QUEUENAME}_consumers=${QUEUECONS}"
  printVerbose "Name: ${QUEUENAME}, Size: ${QUEUESIZE}, Consumers: ${QUEUECONS}"

  # Check if this queue is not excluded:
  EXCLUDED=0
  for exqueue in ${EXCLUDEDQUEUES}
  do
    if [[ ${exqueue} == ${QUEUENAME} ]]; then
      EXCLUDED=1
    fi
  done
  if [[ ${EXCLUDED} -eq 1 ]]; then
    continue
  fi

  # Check size:
  if [[ ${QUEUESIZE} -eq 0 ]]; then
    PERFORMANCE="${PERFORMANCE} ${QUEUENAME}_time=0s;${WARNTIME};${CRITTIME}"
    continue
  fi
  
  # Check consumers:
  if [[ ${QUEUECONS} -eq 0 ]]; then
    echo "1,WARNING - La cola ${QUEUENAME} tiene ${QUEUESIZE} mensajes pero no tiene consumidores" >> ${ERRORS}
  fi
  
  # Check messages in queue:
  MESSAGESFILE="/tmp/check_activemq_${QUEUENAME}_messages_$$.tmp"
  curl -s --get --output "${MESSAGESFILE}" --connect-timeout "${TIMEOUT}" --user "${USERPASSWD}" --url "http://${HOSTIP}:8161/admin/browse.jsp?JMSDestination=${QUEUENAME}"
  # Checl connection errors:
  if [[ ! -s ${MESSAGESFILE} ]]; then
    echo "${STATE_UNKNOWN},UNKNOWN - Error al obtener mensajes de la cola ${QUEUENAME}" >> ${ERRORS}
    continue
  fi
  # Parse oldest message from list:
  OLDESTMSG=$(sed -n '/<table.*id="messages".*>/,/<\/table>/p' ${MESSAGESFILE} | sed 's/^[\ \t]*//g' | tr -d '\n' | sed 's/<\/TR[^>]*>/\n/Ig'  | sed 's/<\/\?\(TABLE\|TBODY\|TR\|TH\|A\)[^>]*>//Ig' | sed 's/^<T[DH][^>]*>\|<\/\?T[DH][^>]*>$//Ig' | sed 's/<\/T[DH][^>]*><T[DH][^>]*>/,/Ig' | cut -d',' -f7 | sort | head -1)
  printVerbose "Oldest message: ${OLDESTMSG:0:19}"
  MAXTIME=$(date --date "${OLDESTMSG:0:19}" +%s)
  printVerbose "Max time: ${MAXTIME}"
  # Calculate time passed in seconds:
  MSGAGE=$((${CURTIMESTMP} - ${MAXTIME}))
  printVerbose "Message age: ${MSGAGE}"
  PERFORMANCE="${PERFORMANCE} ${QUEUENAME}_time=${MSGAGE}s;${WARNTIME};${CRITTIME}"
  # Compare value to thresholds:
  if [[ ${MSGAGE} -gt ${CRITTIME} ]]; then
    echo "${STATE_CRITICAL},CRITICAL - La cola ${QUEUENAME} tiene ${QUEUESIZE} mensajes hace ${MSGAGE} segundos" >> ${ERRORS}
  else
    if [[ ${MSGAGE} -gt ${WARNTIME} ]]; then
      echo "${STATE_WARNING},WARNING - La cola ${QUEUENAME} tiene ${QUEUESIZE} mensajes hace ${MSGAGE} segundos" >> ${ERRORS}
    fi
  fi
  # Remove temp file:
  if [[ -s ${MESSAGESFILE} ]]; then
    rm ${MESSAGESFILE}
  fi

done # for queue

# Check for errors:
TEXTMSG="OK - Todas las colas sin problemas"
EXITCODE=${STATE_OK}
if [[ -s ${ERRORS} ]]; then
  printFileVerbose ${ERRORS}
  TEXTMSG=$(cat ${ERRORS} | sort -r | cut -d',' -f2)
  EXITCODE=$(cat ${ERRORS} | sort -r | cut -d',' -f1 | head -1)
  rm ${ERRORS}
fi

# Add performance metrics:
TEXTMSG="${TEXTMSG} | ${PERFORMANCE}"

# Report results:
echo "${TEXTMSG}"
exit "${EXITCODE}"

