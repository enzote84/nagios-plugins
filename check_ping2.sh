#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check Ping2 Plugin
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   ./check_ping2.sh -H1 IP1 -H2 IP2
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
	echo "Usage: $PROGNAME [ -H1 ip1 -H2 ip2 ] | [-v | -h]"
	echo ""
	echo "  -h  Show this page"
	echo "  -v  Plugin Version"
	echo "  -H1 First IP address"
	echo "  -H2 Second IP address"
	echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 1 ]; then
	echo "Insufficient arguments"
	print_usage
	exit $STATE_UNKNOWN
fi
# Grab the command line arguments
HOSTADDR1_SET=0
HOSTADDR2_SET=0
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
		-H1)
			shift
			HOSTADDR1=$1
			HOSTADDR1_SET=1
			;;
		-H2)
			shift
			HOSTADDR2=$1
			HOSTADDR2_SET=1
			;;
		*)
			echo "Unknown argument: $1"
			print_usage
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done
# Check parameters correctness:
if [ $HOSTADDR1_SET -eq 0 ] || [ $HOSTADDR2_SET -eq 0 ]; then
	echo "Wrong parameters"
	print_usage
	exit $STATE_UNKNOWN
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check ping for each address
#
PSTATUS1=`ping -c 2 -i 0.2 -q $HOSTADDR1|grep received|awk '{if($4 >= 1) print 0; else print 1;}'`
PSTATUS2=`ping -c 2 -i 0.2 -q $HOSTADDR2|grep received|awk '{if($4 >= 1) print 0; else print 1;}'`
RESULT=$(($PSTATUS1 * 2 + $PSTATUS2))
case $RESULT in
	0)
		FINAL_STATUS="OK - Both address responding"
		RETURN_STATUS=$STATE_OK
		;;
	1)
		FINAL_STATUS="WARNING - $HOSTADDR2 not responding"
		RETURN_STATUS=$STATE_WARNING
		;;
	2)
		FINAL_STATUS="WARNING - $HOSTADDR1 not responding"
		RETURN_STATUS=$STATE_WARNING
		;;
	3)
		FINAL_STATUS="CRITICAL - $HOSTADDR1 and $HOSTADDR2 not responding"
		RETURN_STATUS=$STATE_CRITICAL
		;;
esac

echo $FINAL_STATUS
exit $RETURN_STATUS

