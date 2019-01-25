#!/bin/bash
#
# Nagios script to check another check N times before turning red
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#   ./check_ntimes.sh -N 2 -P '/usr/local/nagios/libexec/check_nt -H localhost'
#   This script will execute the check indicated with -P parameter.
#   If that check fails, it will create a temporary file (in /tmp) to hold that result.
#   But it will return 0, telling Nagios that the result was OK. After 2 (the value
#   passed in -N parameter) consecutive times that check fails, it will return the
#   same result of the original check.
#
# NOTES:
#   Make sure that nagios user is defined in HMC and it has a ssh public key.
#
# SETUP:
# 1.- Copy the plugin to Nagios Server: /usr/local/nagios/libexec/check_ntimes.sh
# 2.- Test it: 
#   /usr/local/nagios/libexec/check_ntimes.sh -N 2 -P '/usr/local/nagios/libexec/check_nt -V'
# 3.- Create a command in nagios: 
#   define command { 
#     command_name check_ntimes 
#     command_line $USER1$/check_ntimes.sh -N $ARG1$ -P '$ARG2$'
#   }
# 4.- Service definition example:
#   define service{
#     use generic-service
#     host_name somehost
#     service_description someservice
#     check_command check_ntimes!2!$USER1$/check_nt -H $HOSTADDRESS$ -V
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
  echo "Usage: $PROGNAME [-N times -P 'check'] | [-V | -h]"
  echo ""
  echo "  -h  Show this page"
  echo "  -V  Plugin Version"
  echo "  -N  Times to check before turning red"
  echo "  -P  Check command to execute"
  echo ""
  echo "Example: $PROGNAME -N 2 -P '/usr/local/nagios/libexec/check_nt -V'"
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
    -N)
      shift
      NTIMES=$1
      ;;
    -P)
      shift
      CHECKCMD=$1
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
# Parse command argument to create a unique temporary file name
#
UNIQUECMD=`echo $CHECKCMD|sed "s/[^a-zA-Z]//g"`

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Define temporary metrics file
#
METRICFILE=/tmp/nagios_ntimes_$UNIQUECMD.data

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform check and save result code
#
RESULT=`eval "$CHECKCMD"`
RETCOD=`echo $?`

# If check is OK, then delete metric file and report result as is:
if [[ $RETCOD -eq $STATE_OK ]]; then
  if [[ -f $METRICFILE ]]; then
    rm -f $METRICFILE
  fi
else
  # For other states, compare with the last N results:
  echo $RETCOD >> $METRICFILE
  ERRORCOUNT=`cat $METRICFILE | wc -l`
  if [[ $ERRORCOUNT -lt $NTIMES ]]; then
    RETCOD=$STATE_OK
    RESULT=`echo $RESULT|sed "s/WARNING/OK/g"|sed "s/ERROR/OK/g"`
  fi
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Return final status and exit code
#
echo $RESULT
exit $RETCOD

