#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check Failed Logins in RedHat Plugin
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   ./check_failed_logins.sh -w <WLEVEL> -c <CLEVEL>
#
# SETUP (with NRPE, with other plugin should be a similar process):
# 1.- Copy the plugin to the RedHat server you want to monitor.
#   /usr/lib64/nagios/plugins/check_failed_logins_rh.sh
# 2.- Define an entry in nrpe.cfg:
#   command[check_failed_logins]=/usr/lib64/nagios/plugins/check_failed_logins_rh.sh -w 5 -c 10 2>&1
# 3.- Restart NRPE service.
# 4.- Create a command in nagios: 
#   define command { 
#     command_name check_failed_logins_rh 
#     command_line $USER1$/check_failed_logins_rh.sh -w $ARG1$ -c $ARG2$
#   }
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
	echo "Usage: $PROGNAME [ -w WarnValue -c CritValue ] | [-v | -h]"
	echo ""
	echo "  -h  Show this page"
	echo "  -v  Plugin Version"
	echo "  -w  Warning value for failed login attempts in the last hour"
	echo "  -c  Critical value for failed login attempts in the last hour"
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
WVALUE=0
CVALUE=0
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
		-w)
			shift
			WVALUE=$1
			;;
		-c)
			shift
			CVALUE=$1
			;;
		*)
			echo "Unknown argument: $1"
			print_usage
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done
# Check argument correctness:
if [ $WVALUE -eq 0 ] || [ $CVALUE -eq 0 ]; then
	echo "Invalid arguments"
	print_usage
	exit $STATE_UNKNOWN
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check failed logins
#
DATE=`date -d '1 hour ago' "+%b %d"`
#HOUR_AGO=`TZ=GMT+4 date "+%H:%M:%S"`
HOUR_AGO=`date -d '1 hour ago' "+%H:%M:%S"`
HAS_FAILED_LAST_HOUR=`grep "$DATE" /var/log/secure|grep "Failed password"|awk -v h="$HOUR_AGO" 'BEGIN{c = 0;}{if($3 > h) c = c + 1;}END{print c;}'`
if [ $HAS_FAILED_LAST_HOUR -eq 0 ]; then
	FINAL_STATUS="OK - No failed logins in last hour|failed=0"
	RETURN_STATUS=$STATE_OK
else
	RECENT_ATTEMPTS=`grep "$DATE" /var/log/secure|grep "Failed password"|awk -v h="$HOUR_AGO" '{if($3 > h) for(i=1;i<=NF;i++) if($i == "from") print $(i+1);}'|cut -d "=" -f 2|uniq -c|head -1`
	N_ATTEMPTS=`echo "$RECENT_ATTEMPTS"|awk '{print $1;}'`
	HOST_ATTEMPTING=`echo "$RECENT_ATTEMPTS"|awk '{print $2;}'|sed "s/[()]//g"`
	if [ $N_ATTEMPTS -ge $CVALUE ]; then
		FINAL_STATUS="CRITICAL - $N_ATTEMPTS failed login attempts from $HOST_ATTEMPTING|failed=$N_ATTEMPTS"
		RETURN_STATUS=$STATE_CRITICAL
	elif [ $N_ATTEMPTS -ge $WVALUE ]; then
		FINAL_STATUS="WARNING - $N_ATTEMPTS failed login attempts from $HOST_ATTEMPTING|failed=$N_ATTEMPTS"
		RETURN_STATUS=$STATE_WARNING
	else
		FINAL_STATUS="OK - $N_ATTEMPTS failed login attempts from $HOST_ATTEMPTING|failed=$N_ATTEMPTS"
		RETURN_STATUS=$STATE_OK
	fi
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Return final status and exit code
#
echo $FINAL_STATUS
exit $RETURN_STATUS

