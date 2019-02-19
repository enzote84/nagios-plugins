#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios Availability Report
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   ./report_availability.sh -Y 2018 -M 1 -D 1
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Report info
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
  echo "Usage: $PROGNAME -SY <start_year> -SM <start_month> -SD <start_day> -EY <end_year> -EM <end_month> -ED <end_day> | -h | -v"
  echo ""
  echo "  -h  Show this page"
  echo "  -v  Report Version"
  echo "  -Y  Year"
  echo "  -M  Month"
  echo "  -D  Day"
  echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 1 ]; then
  print_usage
  exit -1
fi
# Grab the command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h)
       print_usage
       exit 0
       ;;
    -v)
       print_version
       exit $STATE_OK
       ;;
    -Y)
       shift
       YEAR=$1
       ;;
    -M)
       shift
       MONTH=$1
       ;;
    -D)
       shift
       DAY=$1
       ;;
  esac
  shift
done

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Commands
#
AVAILABILITY=/usr/local/nagios/sbin/avail.cgi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Variables
#
export REQUEST_METHOD=HEAD
export REMOTE_USER=nagiosadmin
export QUERY_STRING="show_log_entries=&host=all&timeperiod=custom&smon=$MONTH&sday=$DAY&syear=$YEAR&shour=0&smin=0&ssec=0&emon=$MONTH&eday=$DAY&eyear=$YEAR&ehour=23&emin=59&esec=59&assumeinitialstates=yes&assumestateretention=yes&initialassumedstate=0&backtrack=1&csvoutput="

DATE="$YEAR/$MONTH/$DAY"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Execute query
#
#RESULT=`$AVAILABILITY |grep -v "Cache-Control" |grep -v "Pragma" |grep -v "Last-Modified" |grep -v "Expires" |grep -v "Content-type" |grep -v "Content-Disposition" |awk 'NF {print $0;}'`
$AVAILABILITY |tail -n +9 |awk -v date="$DATE" -F', ' 'BEGIN{print "DATE,HOST,DOWN%";}{print date","$1","$18;}'


