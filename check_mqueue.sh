#!/bin/bash
#
# Nagios plugin to check queued messages
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   /usr/local/nagios/libexec/check_mqueue.sh -U nagios -N 1 -M 0
#
# SETUP:
# 1.- Copy the plugin to Nagios Server: /usr/local/nagios/libexec/check_mqueue.sh
# 2.- Test it: 
#   /usr/local/nagios/libexec/check_mqueue.sh -U nagios -N 1 -M 0
# 3.- Create a command in nagios: 
#   define command { 
#     command_name check_mqueue
#     command_line $USER1$/check_mqueue.sh -U '$ARG1$' -N '$ARG2$' -M '$ARG3$'
#   }
# 4.- Service definition example:
#   define service{
#     use generic-service
#     host_name somehost
#     service_description someservice
#     check_command check_mqueue!nagios!1!0
#   }
#
# COMMENTS ON VERSIONS:
# 1.0 Base
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
AUTHOR="DEMR"
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
  echo "Usage: $PROGNAME -U <user> -N <number_of_queues> -M <queued_messages> | [-V | -h]"
  echo ""
  echo "  -h  Show this page"
  echo "  -V  Plugin Version"
  echo "  -U  User running the process"
  echo "  -N  Max number of queue allowed. Ussually 1"
  echo "  -M  Max number of messages queued. Ussually 0"
  echo ""
  echo "Example: $PROGNAME -U nagios -N 1 -M 0"
  echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Make sure the correct number of command line arguments have been supplied
if [[ $# -lt 1 ]]; then
  print_usage
  exit $STATE_UNKNOWN
fi
# Define some default parameters:
USER="nagios"
NQUEUE="1"
MQUEUE="0"
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
    -U)
      shift
      USER=$1
      ;;
    -N)
      shift
      NQUEUE=$1
      ;;
    -M)
      shift
      MQUEUE=$1
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
# Commands and constants
#
# Commands depends on Operating System
# TODO: Add other OS, like AIX.
OS=$(uname)
case "$OS" in
  Linux)
    IPCSQ="ipcs -q"
    ;;
  *)
    echo "Operating System not supported: ${OS}"
    exit $STATE_UNKNOWN
    ;;
esac

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
# Number of queues:
NUMBEROFQUEUES=$($IPCSQ | grep "$USER" | wc -l)
# Max queued messages:
# The 6th column is the queued message number
QUEUEDMESSAGES=$($IPCSQ | grep "$USER" | awk 'BEGIN{maxm=0;} {if($6 > maxm) maxm=$6;} END{print maxm;}')
if [[ $NUMBEROFQUEUES -gt $NQUEUE ]] || [[ $QUEUEDMESSAGES -gt $MQUEUE ]]; then
  RESULT="WARNING - User: ${USER}. Queues: ${NUMBEROFQUEUES}. Messages: ${QUEUEDMESSAGES}"
  CODE=$STATE_WARNING
else
  RESULT="OK - User: ${USER}. Queues: ${NUMBEROFQUEUES}. Messages: ${QUEUEDMESSAGES}"
  CODE=$STATE_OK
fi
PERF="queues=${NUMBEROFQUEUES}; messages=${QUEUEDMESSAGES}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Report results
#
echo "${RESULT} | ${PERF}"
exit $CODE

