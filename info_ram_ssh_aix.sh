#!/bin/sh
#
# Script to report LPAR's RAM
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
TEMPFILE="/tmp/${HOSTNAME}.ram.log"

# Collect data:
ssh $HOSTNAME "svmon" > $TEMPFILE

# Page size in KB:
PAGESIZE=4

# Calculate assigned and used memory:
TOTALPAGES=`cat $TEMPFILE|grep "memory"|awk '{print $2;}'`
TOTALRAM=`echo "scale=2; ${TOTALPAGES}*${PAGESIZE}/1024/1024"|bc -l`
USEDPAGES=`cat $TEMPFILE|grep "memory"|awk '{print $3;}'`
USEDRAM=`echo "scale=2; ${USEDPAGES}*${PAGESIZE}/1024/1024"|bc -l`
PERUSEDRAM=`echo "scale=2; ${USEDRAM}/${TOTALRAM}*100"|bc -l`
TOTALRAMUNIT="GB"

# Inform result and metrics:
RESULTADO="RAM: assigned: ${TOTALRAM}${TOTALRAMUNIT}, used: ${PERUSEDRAM}%"
PERFORMANCE="assigned=${TOTALRAM}${TOTALRAMUNIT} usage=${PERUSEDRAM}% ram=${USEDRAM}${TOTALRAMUNIT};;;0;${TOTALRAM}"
echo "${RESULTADO}|${PERFORMANCE}"

# Erase temporary data:
rm $TEMPFILE

# End
exit $STATE_OK

