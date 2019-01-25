#!/bin/sh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Storwize v7000 performance check
#
# Version: 1.0
# Author: DEMR
# Support: emedina@enersa.com.ar
#
# Example usage:
#
#   ./check_ibm_v7000_perf.sh -H 192.168.129.64 -K /home/nagios/.ssh/id_rsa
#
#
# NOTES:
#   Make sure that nagios user is defined in v7000 and it has a ssh public key.
#   You can change the user in the QUERY section:
#     QUERY=`ssh -i $SSHKEY nagios@$HOSTNAME ...
#   Use nagios's private key when invoking this script.
#
# COMMENTS ON VERSIONS:
# 1.0 Base
# 1.1 Changed single [] for [[]] (Thanks Andrew Haji)
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
VERSION="1.1"
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
	echo "Usage: $PROGNAME [-H <IP> -K <key>] | [-v | -h]"
	echo ""
	echo "  -h  Show this page"
	echo "  -v  Plugin Version"
	echo "  -H  IP or Hostname of V7000 cluster"
	echo "  -K  Nagios's SSH Public Key"
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
		-K)
			shift
			SSHKEY=$1
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
# Check v7000 performance status
#
# Perform query:
QUERY=`ssh -i $SSHKEY nagios@$HOSTNAME "lssystemstats"`
# Separate relevant values for alerts:
CPU_PC=`echo "$QUERY"|grep "^cpu_pc*" | awk '{print $2;}'`
COMPRESSION_CPU_PC=`echo "$QUERY"|grep "^compression_cpu_pc*" | awk '{print $2;}'`
WRITE_CACHE_PC=`echo "$QUERY"|grep "^write_cache_pc*" | awk '{print $2;}'`
TOTAL_CACHE_PC=`echo "$QUERY"|grep "^total_cache_pc*" | awk '{print $2;}'`
BIGGEST_LATENCY=`echo "$QUERY"|grep "_ms " | awk 'BEGIN{max=0}{if($2 > max) max = $2;}END{print max;}'`
# Gather other values to view in performance chart:
FC_MB=`echo "$QUERY"|grep "^fc_mb*" | awk '{print $2;}'`
FC_IO=`echo "$QUERY"|grep "^fc_io*" | awk '{print $2;}'`
SAS_MB=`echo "$QUERY"|grep "^sas_mb*" | awk '{print $2;}'`
SAS_IO=`echo "$QUERY"|grep "^sas_io*" | awk '{print $2;}'`
ISCSI_MB=`echo "$QUERY"|grep "^iscsi_mb*" | awk '{print $2;}'`
ISCSI_IO=`echo "$QUERY"|grep "^iscsi_io*" | awk '{print $2;}'`
# Thresholds values (adjust to fit your needs):
WCPU=80
CCPU=90
WCOMP=80
CCOMP=90
WWCAC=80
CWCAC=90
WTCAC=90
CTCAC=95
WLAT=200
CLAT=500
# Analysis (can be better codded):
if [[ $CPU_PC -gt $CCPU ]] || [[ $COMPRESSION_CPU_PC -gt $CCOMP ]] || [[ $WRITE_CACHE_PC -gt $CWCAC ]] || [[ $TOTAL_CACHE_PC -gt $CTCAC ]] || [[ $BIGGEST_LATENCY -gt $CLAT ]]; then
	FINAL_STATUS="CRITICAL"
	RETURN_STATUS=$STATE_CRITICAL
elif [[ $CPU_PC -gt $WCPU ]] || [[ $COMPRESSION_CPU_PC -gt $WCOMP ]] || [[ $WRITE_CACHE_PC -gt $WWCAC ]] || [[ $TOTAL_CACHE_PC -gt $WTCAC ]] || [[ $BIGGEST_LATENCY -gt $WLAT ]]; then
	FINAL_STATUS="WARNING"
	RETURN_STATUS=$STATE_WARNING
else
	FINAL_STATUS="OK"
	RETURN_STATUS=$STATE_OK
fi
# Add metrics:
FINAL_STATUS="$FINAL_STATUS - CPU: $CPU_PC%, Compression CPU: $COMPRESSION_CPU_PC%, Write Cache: $WRITE_CACHE_PC%, Total Cache: $TOTAL_CACHE_PC%, Latency: $BIGGEST_LATENCY ms"
# Performance string:
PERFORMANCE="cpu=$CPU_PC;comp_cpu=$COMPRESSION_CPU_PC;wcache=$WRITE_CACHE_PC;tcache=$TOTAL_CACHE_PC;latency=$BIGGEST_LATENCY"
PERFORMANCE="$PERFORMANCE;fc_mb=$FC_MB;fc_io=$FC_IO;sas_mb=$SAS_MB;sas_io=$SAS_IO;iscsi_mb=$ISCSI_MB;iscsi_io=$ISCSI_IO"
FINAL_STATUS="$FINAL_STATUS|$PERFORMANCE"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Return final status and exit code
#
echo $FINAL_STATUS
exit $RETURN_STATUS

