#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# IBM BladeCenter Plugin
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   ./check_ibm_bladecenter.sh -H 192.168.129.64 -C check_to_perform
#
# Notes:
#   This plugin requires check_snmp plugin in the same folder.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios return codes
#
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Some anotations
#
# Performance: | 'label'=value[UOM];[warn];[crit];[min];[max]
# Plugin Development: https://nagios-plugins.org/doc/guidelines.html

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
	echo "Usage: $PROGNAME [ -H <IP> -K <key> -C [health|temp] ] | [-v | -h]"
	echo ""
	echo "  -h  Show this page"
	echo "  -v  Plugin Version"
	echo "  -H  IP or Hostname of BladeCenter"
	echo "  -C  Check to be performed:"
	echo "      system-health (Check health of all components)"
	echo "      ambient-temp  (Check ambient temperature level)"
    echo "      mm-temp       (Check MM temperature level)"
    echo "      system-power  (Report BladeCenter current power consumption)"
	echo ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse parameters
#
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
		-C)
			shift
			case "$1" in
				system-health)
					COMMAND="$1"
					;;
				ambient-temp)
					COMMAND="$1"
					;;
                mm-temp)
					COMMAND="$1"
					;;
                system-power)
                    COMMAND="$1"
                    ;;
				*)
					echo "Unknown argument: $1"
					print_usage
					exit $STATE_UNKNOWN
					;;
			esac
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
# Commands
#
SNMPVERSION=1
SNMPCOMMUNITY="public"
SNMPTIMEOUT=5
SNMPGETCMD="snmpget -v $SNMPVERSION -c $SNMPCOMMUNITY -t $SNMPTIMEOUT"
SNMPWALKCMD="snmpwalk -v $SNMPVERSION -c $SNMPCOMMUNITY -t $SNMPTIMEOUT"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# MIB definitions
#
BLADEBASEMIB=".1.3.6.1.4.1.2.3.51.2."
SYSTEMSTATEMIB=$BLADEBASEMIB"2.7.1.0"
AMBIENTTEMPMIB=$BLADEBASEMIB"2.1.5.1.0"
MMTEMPMIB=$BLADEBASEMIB"2.1.1.2.0"
POWERDOM1MIB=$BLADEBASEMIB"2.10.2.1.1.7"
POWERDOM2MIB=$BLADEBASEMIB"2.10.3.1.1.7"
POWERMIB=$BLADEBASEMIB"2.10.1.1.1"
POWERINUSE1MIB=$BLADEBASEMIB"2.10.1.1.1.10.1"
POWERINUSE2MIB=$BLADEBASEMIB"2.10.1.1.1.10.2"
POWERMAX1MIB=$BLADEBASEMIB"2.10.1.1.1.7.1"
POWERMAX2MIB=$BLADEBASEMIB"2.10.1.1.1.7.2"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Thresholds
#
AMBIENTTEMPLOWC=8
AMBIENTTEMPLOWW=15
AMBIENTTEMPWARN=30
AMBIENTTEMPCRIT=37
MMTEMPWARN=50
MMTEMPCRIT=60

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check BladeCenter Status
#
case "$COMMAND" in
	system-health)
		QUERY=`$SNMPGETCMD $HOSTNAME $SYSTEMSTATEMIB|sed "s/.*INTEGER: //"`
        FINAL_STATUS="UNKNOWN - BladeCenter system status is unknown|health=$QUERY"
        RETURN_STATUS=$STATE_UNKNOWN
        if [ $QUERY -eq 0 ]; then
            FINAL_STATUS="CRITICAL - BladeCenter system status is critical|health=$QUERY"
            RETURN_STATUS=$STATE_CRITICAL
        elif [ $QUERY -eq 2 ]; then
            FINAL_STATUS="WARNING - BladeCenter system status is warning|health=$QUERY"
			RETURN_STATUS=$STATE_WARNING
        else
            FINAL_STATUS="OK - BladeCenter system status is OK|health=$QUERY"
			RETURN_STATUS=$STATE_OK
        fi
        ;;
	ambient-temp)
        TEMPPERFAPPEND="C;"$AMBIENTTEMPWARN";"$AMBIENTTEMPCRIT
        QUERY=`$SNMPGETCMD $HOSTNAME $AMBIENTTEMPMIB|sed "s/.*STRING: .\(.*\) Cent.*$/\1/"`
        FINAL_STATUS="UNKNOWN - BladeCenter ambient temperature is unknown|temp="$QUERY$TEMPPERFAPPEND
        RETURN_STATUS=$STATE_UNKNOWN
        if [ "$(echo $QUERY '>' $AMBIENTTEMPCRIT|bc -l)" -eq 1 ] || [ "$(echo $QUERY '<' $AMBIENTTEMPLOWC|bc -l)" -eq 1 ]; then
            FINAL_STATUS="CRITICAL - BladeCenter ambient temperature is "$QUERY" Centigrades|temp="$QUERY$TEMPPERFAPPEND
            RETURN_STATUS=$STATE_CRITICAL
        elif [ "$(echo $QUERY '>' $AMBIENTTEMPWARN|bc -l)" -eq 1 ] || [ "$(echo $QUERY '<' $AMBIENTTEMPLOWW|bc -l)" -eq 1 ]; then
            FINAL_STATUS="WARNING - BladeCenter ambient temperature is "$QUERY" Centigrades|temp="$QUERY$TEMPPERFAPPEND
            RETURN_STATUS=$STATE_WARNING
        else
            FINAL_STATUS="OK - BladeCenter ambient temperature is "$QUERY" Centigrades|temp="$QUERY$TEMPPERFAPPEND
			RETURN_STATUS=$STATE_OK
        fi
		;;
    mm-temp)
        TEMPPERFAPPEND="C;"$MMTEMPWARN";"$MMTEMPCRIT
        QUERY=`$SNMPGETCMD $HOSTNAME $MMTEMPMIB|sed "s/.*STRING: .\(.*\) Cent.*$/\1/"`
        FINAL_STATUS="UNKNOWN - BladeCenter MM temperature is unknown|temp="$QUERY$TEMPPERFAPPEND
        RETURN_STATUS=$STATE_UNKNOWN
        if [ "$(echo $QUERY '>' $MMTEMPCRIT | bc -l)" -eq 1 ]; then
            FINAL_STATUS="CRITICAL - BladeCenter MM temperature is "$QUERY" Centigrades|temp="$QUERY$TEMPPERFAPPEND
            RETURN_STATUS=$STATE_CRITICAL
        elif [ "$(echo $QUERY '>' $MMTEMPWARN | bc -l)" -eq 1 ]; then
            FINAL_STATUS="WARNING - BladeCenter MM temperature is "$QUERY" Centigrades|temp="$QUERY$TEMPPERFAPPEND
            RETURN_STATUS=$STATE_WARNING
        else
            FINAL_STATUS="OK - BladeCenter MM temperature is "$QUERY" Centigrades|temp="$QUERY$TEMPPERFAPPEND
			RETURN_STATUS=$STATE_OK
        fi
		;;
    system-power)
        # Get current power values:
        QUERY1=`$SNMPGETCMD $HOSTNAME $POWERINUSE1MIB|sed "s/.*STRING: .\(.*\)..$/\1/"`
        QUERY2=`$SNMPGETCMD $HOSTNAME $POWERINUSE2MIB|sed "s/.*STRING: .\(.*\)..$/\1/"`
        # Calculate total power in use:
        QUERY3=`echo $(($QUERY1 + $QUERY2))`
        # Get maximum powers
        QUERY4=`$SNMPGETCMD $HOSTNAME $POWERMAX1MIB|sed "s/.*STRING: .\(.*\)..$/\1/"`
        QUERY5=`$SNMPGETCMD $HOSTNAME $POWERMAX2MIB|sed "s/.*STRING: .\(.*\)..$/\1/"`
        # Calculate total maximum power:
        QUERY6=`echo $(($QUERY4 + $QUERY5))`
        # Report result:
        FINAL_STATUS="OK - BladeCenter current power is "$QUERY3" Watts|power="$QUERY3"W;;;0;"$QUERY6
        RETURN_STATUS=$STATE_OK
        ;;
esac

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Return final status and exit code
#
echo $FINAL_STATUS
exit $RETURN_STATUS

