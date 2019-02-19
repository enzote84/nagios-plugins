#!/bin/sh
#
# Script to report LPAR's CPU
#

# Nagios return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Plugin info
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
  echo "Usage: $PROGNAME [-H <IP>] | [-v | -h]"
  echo ""
  echo "  -h  Show this page"
  echo "  -v  Plugin Version"
  echo "  -H  IP or Hostname of LPAR"
  echo ""
}

# Parse parameters
# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 1 ]; then
  print_usage
  exit $STATE_UNKNOWN
fi
# Grab the command line arguments
while [ $# -gt 0 ]; do
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
      HOSTNAME=$1
      ;;
    *)
      echo "Unknown argument: $1"
      print_usage
      exit $STATE_UNKNOWN
      ;;
  esac
  shift
done

# Temp file:
TEMPFILE="/tmp/${HOSTNAME}.cpu.log"

# Collect data:
ssh $HOSTNAME "vmstat 1 1" > $TEMPFILE

# Calculate entitlted CPU, percentaje and real usage:
ENTCPU=`cat $TEMPFILE|grep "System configuration:"|awk -F "=" '{print $4;}'`
PERENTCPU=`tail -1 $TEMPFILE|awk '{print $19;}'`
USEDCPU=`echo "${ENTCPU}*${PERENTCPU}/100"|bc -l`

# Report result and performance metrics:
RESULTADO="CPU: assigned: ${ENTCPU}, used: ${PERENTCPU}%"
PERFORMANCE="assigned=${ENTCPU} usage=${PERENTCPU}% cpu=${USEDCPU};;;0;${ENTCPU}"
echo "${RESULTADO}|${PERFORMANCE}"

# Erase temporary data:
rm $TEMPFILE

# End
exit $STATE_OK

