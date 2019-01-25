#!/bin/sh
#
# Check HMC Service Events
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#   ./check_hmc_svcevents.sh -H 192.168.129.64 -K /home/nagios/.ssh/id_rsa
#
# NOTES:
#   Make sure that nagios user is defined in HMC and it has a ssh public key.
#
# SETUP:
# 1.- Login to Nagios Server with nagios user. 
# 2.- Generate a SSH key. 
# 3.- Login to HMC, create a nagios user and attach the public SSH key to it. 
# 4.- Copy the plugin to Nagios Server: /usr/local/nagios/libexec/check_hmc_svcevents.sh 
# 5.- Test it: 
#   /usr/local/nagios/libexec/check_hmc_svcevents.sh -H 192.168.1.100 -K /home/nagios/.ssh/id_rsa 
# 6.- Create a command in nagios: 
#   define command { 
#     command_name check_hmc_svcevents 
#     command_line $USER1$/check_hmc_svcevents.sh -H $HOSTADDRESS$ -K /home/nagios/.ssh/id_rsa 
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
  echo "Usage: $PROGNAME -H <IP> -K <sshkey> | [-v | -h]"
  echo ""
  echo "  -h  Show this page"
  echo "  -v  Plugin Version"
  echo "  -H  IP or Hostname of HMC"
  echo "  -K  User's public ssh key"
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
    -v)
      print_version
      exit $STATE_OK
      ;;
    -H)
      shift
      HMC=$1
      ;;
	-K)
	  shift
	  USERKEY=$1
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
# Check HMC open events
#
RESULT=`ssh -i ${USERKEY} hscroot@$HMC lssvcevents -t hardware --filter "status=open" 2>&1`
OK=`echo $?`
if [[ $OK -ne 0 ]]; then
  echo "Could not connect to HMC: $HMC. $RESULT"
  exit $STATE_UNKNOWN
fi
# Count open events:
EVENTS=`echo $RESULT | grep "problem_num" | wc -l`
if [[ $EVENTS -eq 0 ]]; then
  RETURN_STATUS=$STATE_OK
  FINAL_STATUS="OK - No open service events in HMC"
else
  RETURN_STATUS=$STATE_WARNING
  FINAL_STATUS="WARNING - There are ${EVENTS} open service events. Check HMC"
fi
# Add performance metrics:
FINAL_STATUS="$FINAL_STATUS | events=${EVENTS}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Return final status and exit code
#
echo $FINAL_STATUS
exit $RETURN_STATUS

