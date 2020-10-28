#! /usr/bin/env python
# -*- coding: utf-8 -*-

#
# Check Jenkins Jobs Nagios Plugin
#

import argparse, sys
import jenkins
from datetime import datetime

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios return codes
#
STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3
exit_satus = STATE_OK

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Plugin info
#
PLUGIN_AUTHOR = "BBR"
PLUGIN_VERSION = "1.0"
PLUGIN_CONTACT = "soporte@bbr.cl"
PLUGIN_DESCRIPTION = '''
CHECK JENKINS PLUGIN
This plugin connects to a Jenkins server using python-jenkins api and checks the status of past jobs.
'''
PLUGIN_EPILOG = '''
AUTHOR: {author}
CONTACT: {contact}
'''.format(author=PLUGIN_AUTHOR, contact=PLUGIN_CONTACT)
#PROGNAME = $(basename $0)
#BASEDIR = $(dirname $0)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Auxiliary functions
#
def printVerbose(str):
    if args.verbose_mode:
        print(str)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parse arguments
#
# Define parser:
parser = argparse.ArgumentParser(description=PLUGIN_DESCRIPTION, epilog=PLUGIN_EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.version = parser.prog + PLUGIN_VERSION
parser.add_argument('-v','--version', action='version',
    help="Show plugin version",
    version='%(prog)s ' + PLUGIN_VERSION)
parser.add_argument("--verbose-mode", help="Increase output verbosity", action="store_true")
conn_parameters = parser.add_argument_group('Connection parameters', 'Parameters for Jenkins connection')
conn_parameters.add_argument('-H', '--host',
    help='Jenkins host URL: http://<ip/fqdn>:<port>',
    required=True)
group = conn_parameters.add_mutually_exclusive_group()
group.add_argument('-J', '--job', help='Job name')
group.add_argument('-V', '--view', help='View name')
conn_parameters.add_argument('-u', '--user',
    help='Username',
    required=False)
conn_parameters.add_argument('-p', '--password',
    help='Password',
    required=False)
threshlod_parameters = parser.add_argument_group('Threshold parameters', 'Thresholds values for warning and critical')
threshlod_parameters.add_argument('--warn-running',
    help='Value, in seconds, for the warning threshold of a running job',
    type=int,
    default=900)
threshlod_parameters.add_argument('--crit-running',
    help='Value, in seconds, for the critical threshold of a running job',
    type=int,
    default=1800)
threshlod_parameters.add_argument('--warn-last-run',
    help='Value, in seconds, for the warning threshold of the last time since the job has been issued',
    type=int,
    default=90000)
threshlod_parameters.add_argument('--crit-last-run',
    help='Value, in seconds, for the critical threshold of the last time since the job has been issued',
    type=int,
    default=100800)
threshlod_parameters.add_argument("--error-on-disabled", help="Return CRITICAL if a job is disabled", action="store_true")
threshlod_parameters.add_argument("--error-on-notbuilt", help="Return CRITICAL if a job has not been built", action="store_true")
threshlod_parameters.add_argument("--ignore-period", help="Do not check the period of a job execution", action="store_true")
# Parse arguments:
args = parser.parse_args()
# Assign variables:
jenkins_server = args.host
printVerbose("Server: " + jenkins_server)
if args.job:
    printVerbose("Job: " + args.job)
if args.view:
    printVerbose("View: " + args.view)
if args.user:
    printVerbose("USER: " + args.user)
if args.password:
    printVerbose("PASSWORD: " + args.password)
printVerbose("WARN RUNNING: " + str(args.warn_running))
printVerbose("CRIT RUNNING: " + str(args.crit_running))
printVerbose("WARN LAST RUN: " + str(args.warn_last_run))
printVerbose("CRIT LAST RUN: " + str(args.crit_last_run))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Jenkins functions
#
def connectJenkins(jenkins_server, user = None, password = None):
    try:
        if user and password:
            server = jenkins.Jenkins(jenkins_server, timeout=5, username=user, password=password)
        else:
            server = jenkins.Jenkins(jenkins_server, timeout=5)
        return server
    except:
        print("UNKNOWN - Error al intentar conectar con Jenkins")
        printVerbose(sys.exc_info())
        sys.exit(STATE_UNKNOWN)

def getJobInfo(server, job_name):
    printVerbose("----------------------------------------------")
    printVerbose("JOB NAME: " + job_name)
    try:
        server.assert_job_exists(name=job_name)
        job_info = server.get_job_info(name=job_name)
    except:
        print("UNKNOWN - Error al intentar obtener información del job " + job_name)
        printVerbose(sys.exc_info())
        sys.exit(STATE_UNKNOWN)
    printVerbose("COLOR: " + job_info['color'])
    if (job_info['color'].find('disabled') == -1):
        printVerbose("LAST BUILD: " + str(job_info['lastBuild']['number']))
        printVerbose("LAST COMPLETED BUILD: " + str(job_info['lastCompletedBuild']['number']))
        for report in job_info['healthReport']:
            printVerbose("HEALTH REPORT: " + str(report['score']))
    return job_info

def getBuildInfo(server, job_name, build_number):
    printVerbose(">>> " + job_name + " #" + str(build_number))
    try:
        build_info = server.get_build_info(name=job_name, number=build_number)
    except:
        print("UNKNOWN - Error al intentar obtener información del build " + build_number)
        printVerbose(sys.exc_info())
        sys.exit(STATE_UNKNOWN)
    printVerbose("BUILD #" + str(build_info['number']))
    printVerbose("IS RUNNING: " + str(build_info['building']))
    printVerbose("DURATION: " + str(int(build_info['duration'] / 1000)) + "s")
    printVerbose("ESTIMATED DURATION: " + str(int(build_info['estimatedDuration'] / 1000)) + "s")
    if (build_info['building'] == False):
        printVerbose("RESULT: " + build_info['result'])
    printVerbose("TIMESTAMP: " + str(build_info['timestamp']))
    printVerbose("TEMESTAMP ISO: " + datetime.fromtimestamp(build_info['timestamp'] / 1000).isoformat())
    return build_info

def checkJobStatus(server, job_name):
    job_result = {'status': STATE_OK, 'text': "OK - Job " + job_name + " is SUCCESSFUL", 'duration': "0s"}
    # Get job info:
    job_info = getJobInfo(server, job_name)
    # Check if it is disabled or if it has no builds:
    if (job_info['color'].find('disabled') != -1):
        job_result = {'status': STATE_OK, 'text': "OK - Job " + job_name + " is disabled. Please check: " + job_info['url'], 'duration': "0s"}
        if (args.error_on_disabled):
            job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " is DISABLED. Please check: " + job_info['url'], 'duration': "0s"}
    elif (job_info['color'].find('notbuilt') != -1):
        job_result = {'status': STATE_OK, 'text': "OK - Job " + job_name + " has not been built. Please check: " + job_info['url'], 'duration': "0s"}
        if (args.error_on_notbuilt):
            job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " has NOT BEEN BUILT. Please check: " + job_info['url'], 'duration': "0s"}
    else:
        # Get build info of current process:
        build_info = getBuildInfo(server, job_name, job_info['lastBuild']['number'])
        # Get estimated duration in seconds:
        estimated_duration = int(build_info['estimatedDuration'] / 1000)
        # Get elapsed time:
        current_time = datetime.now()
        elapsed_time = int((current_time - datetime.fromtimestamp(build_info['timestamp'] / 1000)).total_seconds())
        printVerbose("ELAPSED TIME: " + str(elapsed_time) + "s")
        # Check if it is running:
        if (build_info['building']):
            # Check if elapsed time is acceptable:
            # CRITICAL if it has been 30 minutes (1800 seconds) more than usual:
            if (elapsed_time > (estimated_duration + args.crit_running)):
                job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " is taking 100% more time than espected: " + str(elapsed_time) + " seconds. Please check: " + job_info['url'], 'duration': "0s"}
            # WARNING if it has been 15 minutes (900 seconds) more than usual:
            elif (elapsed_time > (estimated_duration + args.warn_running)):
                job_result = {'status': STATE_WARNING, 'text': "WARNING - Job " + job_name + " is taking 50% more time than espected: " + str(elapsed_time) + " seconds. Please check: " + job_info['url'], 'duration': "0s"}
            else:
                # Evaluate last completed build:
                build_info = getBuildInfo(server, job_name, job_info['lastCompletedBuild']['number'])
                if build_info['result'] != 'SUCCESS':
                    job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " completed with errors. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
                else:
                    # Check if it has been issued not too long ago (25 hours warning, 30 hours critical):
                    elapsed_time = int((current_time - datetime.fromtimestamp(build_info['timestamp'] / 1000)).total_seconds())
                    if ((not args.ignore_period) and (elapsed_time > (args.crit_last_run + estimated_duration))):
                        job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " has not been completed in the normal period. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
                    elif ((not args.ignore_period) and (elapsed_time > (args.warn_last_run + estimated_duration))):
                        job_result = {'status': STATE_WARNING, 'text': "WARNING - Job " + job_name + " has not been completed in the normal period. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
                    else:
                        job_result = {'status': STATE_OK, 'text': "OK - Job " + job_name + " is SUCCESSFUL. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
        else:
            # Evaluate last build:
            if build_info['result'] != 'SUCCESS':
                job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " completed with errors. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
            else:
                # Check if it has been issued not too long ago (25 hours warning, 30 hours critical):
                if ((not args.ignore_period) and (elapsed_time > (args.crit_last_run + estimated_duration))):
                    job_result = {'status': STATE_CRITICAL, 'text': "CRITICAL - Job " + job_name + " has not been completed in the normal period. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
                elif ((not args.ignore_period) and (elapsed_time > (args.warn_last_run + estimated_duration))):
                    job_result = {'status': STATE_WARNING, 'text': "WARNING - Job " + job_name + " has not been completed in the normal period. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
                else:
                    job_result = {'status': STATE_OK, 'text': "OK - Job " + job_name + " is SUCCESSFUL. Please check: " + job_info['url'], 'duration': (str(int(build_info['duration'] / 1000)) + "s")}
    return job_result

def checkViewStatus(server, view_name):
    view_result = {'status': STATE_OK, 'text': "OK - All jobs in view " + view_name + " are ok", 'duration': "0s"}
    printVerbose("==============================================")
    printVerbose("VIEW: " + view_name)
    try:
        server.assert_view_exists(name=view_name)
        job_list = server.get_jobs(view_name=view_name)
    except:
        print("UNKNOWN - Error al intentar obtener información de la vista " + view_name)
        printVerbose(sys.exc_info())
        sys.exit(STATE_UNKNOWN)
    # Check each job of the view:
    max_job_error = STATE_OK
    sum_duration = 0
    for job in job_list:
        job_result = checkJobStatus(server, job['name'])
        printVerbose("JOB STATUS: " + str(job_result['status']))
        printVerbose("TEXT: " + job_result['text'])
        sum_duration = sum_duration + int(job_result['duration'][0:-1])
        if (job_result['status'] != STATE_OK):
            if (job_result['status'] > max_job_error):
                view_result = job_result
                view_result['duration'] = str(sum_duration) + "s"
                max_job_error = job_result['status']
    # Check if there are failed jobs:
    if (max_job_error == STATE_OK):
        view_result['duration'] = str(sum_duration) + "s"
        view_result['text'] = view_result['text'] + ". Server: " + jenkins_server
    return view_result

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
if args.user and args.password:
    server = connectJenkins(jenkins_server, args.user, args.password)
else:
    server = connectJenkins(jenkins_server)
if args.job:
    result = checkJobStatus(server, args.job)
elif args.view:
    result = checkViewStatus(server, args.view)
print(result['text'] + "|duration=" + str(result['duration']))
sys.exit(result['status'])


