#!/bin/sh
#
# Script to report LPAR's Storage
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

# Variables:
TOTALSTORAGE=0
USEDSTORAGE=0

# Unit convertion function (convert to GB):
convertgb () {
  case $1 in
    kilobyte)
      echo "9.53674e-07"
      ;;
    megabyte)
      echo "0.000976562"
      ;;
    gigabyte)
      echo "1"
      ;;
    terabyte)
      echo "1024"
      ;;
    *)
      echo "1"
      ;;
  esac
}

# Temp file:
TEMPFILE="/tmp/${HOSTNAME}.storage.log"

# Collect data:
VGS=`ssh $HOSTNAME "lsvg -o"`

# For each VG, calculate accumulated total and used space:
for vg in $VGS; do
  ssh $HOSTNAME "lsvg $vg" > $TEMPFILE
  PPSIZE=`cat $TEMPFILE|grep "PP SIZE:"|awk '{print $6;}'`
  PPUNIT=`cat $TEMPFILE|grep "PP SIZE:"|awk '{print $7;}'|awk -F"(" '{print $1;}'`
  MULTIP=`convertgb $PPUNIT`
  TOTALPPS=`cat $TEMPFILE|grep "TOTAL PPs:"|awk '{print $6;}'`
  VGTOTALSTORAGE=`echo "scale=2; ${TOTALPPS}*${PPSIZE}*${MULTIP}"|bc -l`
  TOTALSTORAGE=`echo "${TOTALSTORAGE}+${VGTOTALSTORAGE}"|bc -l`
  USEDPPS=`cat $TEMPFILE|grep "USED PPs:"|awk '{print $5;}'`
  VGUSEDSTORAGE=`echo "scale=2; ${USEDPPS}*${PPSIZE}*${MULTIP}"|bc -l`
  USEDSTORAGE=`echo "${USEDSTORAGE}+${VGUSEDSTORAGE}"|bc -l`
done

# Calculate used space in %:
PERUSEDSTORAGE=`echo "sclae=2; ${USEDSTORAGE}/${TOTALSTORAGE}*100"|bc -l`

# Inform result and performance metrics:
RESULTADO="STORAGE: assigned: ${TOTALSTORAGE}GB, used: ${PERUSEDSTORAGE}%"
PERFORMANCE="assigned=${TOTALSTORAGE}GB usage=${PERUSEDSTORAGE}% storage=${USEDSTORAGE}GB;;;0;${TOTALSTORAGE}"
echo "${RESULTADO}|${PERFORMANCE}"

# Erase temporary data:
rm $TEMPFILE

# End
exit $STATE_OK

