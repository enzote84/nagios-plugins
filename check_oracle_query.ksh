#! /usr/bin/ksh
# check_sql_query
# nagios plugin to execute a specific sql query
# author: Sergei Haramundanis 08-Aug-2006
#
# usage: check_sql_query access_file query_file
#
# Description:
#
# This plugin will execute a sql query and report the elapsed time it took for the values to return
#
# This plugin requires oracle sqlplus (see definition of ORACLE_HOME, PATH and LD_LIBRARY_PATH further on in this script, you may need to
# change them)
#
# contents of access_file must contain database connection information in the following format:
#
# USERNAME username
# PASSWORD password
# CONNECTION_STRING connection_string
#
# contents of query_file must contain sql query information in the following format:
#
# SQL_QUERY specific_sql_query
#
# these are to be used by sqlplus to login to the database and execute the appropriate sql query
#
# Output:
#
# During any run of the plugin, it will execute the sql query
#
# if the query was successful it will return on OK state with the message:
#
# [OK] successful sql query execution | elapsedTime=##secs
#
# if the query was not successful it will return a CRITICAL state with the message:
#
# [CRITICAL] sql query execution failed db_result | elapsedTime=##secs
#
# query execution failure is determined if any ORA- error is received or if the query returned 0 rows
#

cd /usr/local/nagios/bbr/oracle/

if [ "${1}" = "" -o "${1}" = "--help" ]; then
    echo "check_sql_query 1.0"
    echo ""
    echo "nagios plugin to execute a specific sql query"
    echo ""
    echo "This nagios plugin comes with ABSOLUTELY NO WARRANTY."
    echo "You may redistribute copies of this plugin under the terms of the GNU General Public License"
    echo "as long as the original author, edit history and description information remain in place."
    echo ""
    echo "usage: check_sql_query access_file query_file"
    echo "usage: check_sql_query --help"
    echo "usage: check_sql_query --version"
    exit ${STATE_OK}
fi

if [ ${1} == "--version" ]; then
    echo "check_sql_query 1.0"
    echo "This nagios plugin comes with ABSOLUTELY NO WARRANTY."
    echo "You may redistribute copies of this plugin under the terms of the GNU General Public License"
    echo "as long as the original author, edit history and description information remain in place."
    exit ${STATE_OK}
fi

if [ $# -lt 2 ]; then
    echo "[CRITICAL] insufficient arguments"
    exit ${STATE_CRITICAL}
fi

ACCESS_FILE=${1}
QUERY_FILE=${2}

#echo "ACCESS_FILE=\"${ACCESS_FILE}\""
#echo "QUERY_FILE=\"${QUERY_FILE}\""

#SCRIPTPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`
#. ${SCRIPTPATH}/utils.sh # sets correct STATE_* return values
. ./utils.sh

#export ORACLE_HOME=/app/oracle/product/10.2.0
#export PATH=${ORACLE_HOME}/bin:$PATH
#export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:$LD_LIBRARY_PATH
#export TNS_ADMIN=/clareonProd/sched/conf # directory of correct tnsnames.ora

if [ ! -f ${ACCESS_FILE} ]; then
    echo "[CRITICAL] unable to locate access_file ${ACCESS_FILE} from `pwd`"
    exit ${STATE_CRITICAL}
fi

if [ ! -r ${ACCESS_FILE} ]; then
    echo "[CRITICAL] unable to read access_file ${ACCESS_FILE}"
    exit ${STATE_CRITICAL}
fi

if [ `grep "USERNAME " ${ACCESS_FILE} | wc -l` -eq 0 ]; then
    echo "[CRITICAL] unable to locate USERNAME in ${ACCESS_FILE}"
    exit ${STATE_CRITICAL}
fi

if [ `grep "PASSWORD " ${ACCESS_FILE} | wc -l` -eq 0 ]; then
    echo "[CRITICAL] unable to locate PASSWORD in ${ACCESS_FILE}"
    exit ${STATE_CRITICAL}
fi

if [ `grep "CONNECTION_STRING " ${ACCESS_FILE} | wc -l` -eq 0 ]; then
    echo "[CRITICAL] unable to locate CONNECTION_STRING ${ACCESS_FILE}"
    exit ${STATE_CRITICAL}
fi

if [ ! -f ${QUERY_FILE} ]; then
    echo "[CRITICAL] unable to locate query_file ${QUERY_FILE} from `pwd`"
    exit ${STATE_CRITICAL}
fi

if [ ! -r ${QUERY_FILE} ]; then
    echo "[CRITICAL] unable to read query_file ${QUERY_FILE}"
    exit ${STATE_CRITICAL}
fi

if [ `grep "SQL_QUERY " ${QUERY_FILE} | wc -l` -eq 0 ]; then
    echo "[CRITICAL] unable to locate SQL_QUERY in ${QUERY_FILE}"
    exit ${STATE_CRITICAL}
fi

USERNAME=$(grep "^USERNAME" ${ACCESS_FILE}|awk '{print $2}')
PASSWORD=$(grep "^PASSWORD" ${ACCESS_FILE}|awk '{print $2}')
CONNECTION_STRING=$(grep "^CONNECTION_STRING" ${ACCESS_FILE}|awk '{print $2}')

{ while read record;do
    #echo "record=\"${record}\""
    WORD_COUNT=`echo $record | grep "^SQL_QUERY" | wc -w | sed s/\ //g`
    if [ ${WORD_COUNT} -ne 0 ]; then
        SQL_QUERY=`echo $record | sed s/SQL_QUERY\ //g`
        #echo "SQL_QUERY=\"${SQL_QUERY}\""
    fi
done } < ${QUERY_FILE}

#echo "SQL_QUERY=\"${SQL_QUERY}\""

START_TIME=`date +%H%M%S`

# execute query
DB_RESULT=""
DB_RESULT=`sqlplus -s <<EOT
$USERNAME/$PASSWORD@$CONNECTION_STRING
set pagesize 9999
set lines 4096
set head off
set echo off 
set feedback off
${SQL_QUERY}
exit
EOT
`
RETRESULT=$?

END_TIME=`date +%H%M%S`

ERRCNT=`echo ${DB_RESULT} | grep ORA- | wc -l`

if [ ${ERRCNT} -ne 0  -o  ${RETRESULT} -ne 0 ] ; then
    let ELAPSED_TIME=${END_TIME}-${START_TIME}
    if [ ${ERRCNT} -gt 0 ]; then
        ORA_ERROR=`echo ${DB_RESULT} | grep "ORA-"`
        echo "[CRITICAL] sql query execution failed RETRESULT=\"${RETRESULT}\" ORA_ERROR=\"${ORA_ERROR}\" | elapsedTime=${ELAPSED_TIME}secs"
    else
        echo "[CRITICAL] sql query execution failed RETRESULT=\"${RETRESULT}\" DB_RESULT=\"${DB_RESULT}\" | elapsedTime=${ELAPSED_TIME}secs"
    fi
    exit ${STATE_CRITICAL}
fi

#echo "DB_RESULT=\"${DB_RESULT}\""
#echo "${DB_RESULT}"

## show resultset
#let col_count=0
#let rec_count=0
#RECORD=""
#for col_value in ${DB_RESULT}; do
##    echo "col_value=\"${col_value}\""
#    let col_count=col_count+1
#    RECORD=`echo ${RECORD} ${col_value}`
#    if [ col_count -eq 3 ]; then
#        let rec_count=rec_count+1
##        echo "RECORD=\"${RECORD}\""
#
#        # extract return value and datetime
#        set -A COLARRAY `echo ${RECORD}`
#        REC_COL0=${COLARRAY[0]}
#        REC_COL1=${COLARRAY[1]}
#        REC_COL2=${COLARRAY[2]}
#
##        echo "[${rec_count}] REC_COL0=\"${REC_COL0}\""
##        echo "[${rec_count}] REC_COL1=\"${REC_COL1}\""
##        echo "[${rec_count}] REC_COL2=\"${REC_COL2}\""
#
#        # initialize values for next record
#        let col_count=0
#        RECORD=""
#    fi
#done

# View final result
echo "${DB_RESULT}" | egrep -E "WARN|CRIT|OK" > final_result.$$

REVISION_WARN=`cat final_result.$$ | grep WARN | wc -l`
REVISION_CRIT=`cat final_result.$$ | grep CRIT | wc -l`
REVISION_OK=`cat final_result.$$ | grep OK | wc -l`

# Control critical state
if [ ${REVISION_CRIT} -ne 0 ] ; then
    cat final_result.$$ | grep CRIT
    rm -f final_result.$$
    exit ${STATE_CRITICAL}
fi

# Control warning state
if [ ${REVISION_WARN} -ne 0 ] ; then
    cat final_result.$$ | grep WARN
    rm -f final_result.$$
    exit ${STATE_WARNING}
fi

# Control ok state
if [ ${REVISION_OK} -ne 0 ] ; then
    cat final_result.$$ | grep OK
    rm -f final_result.$$
    exit ${STATE_OK}
fi
#let ELAPSED_TIME=${END_TIME}-${START_TIME}
#echo "[OK] successful | elapsedTime=${ELAPSED_TIME} secs"
echo "OK - Sin registros ultimas 2 horas"
rm -f final_result.$$
exit ${STATE_OK}


