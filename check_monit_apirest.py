#! /usr/bin/env python
# -*- coding: utf-8 -*-

#
# Check Monit REST Nagios Plugin
#

import argparse, sys
import requests
import json

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
CHECK MONIT REST PLUGIN
This plugin connects to a M/Monit API Rest and gets the status of all monit jobs.
'''
PLUGIN_EPILOG = '''
AUTHOR: {author}
CONTACT: {contact}
'''.format(author=PLUGIN_AUTHOR, contact=PLUGIN_CONTACT)

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
    help='Server host. Example: as1.test.promar.b2b',
    required=True)
conn_parameters.add_argument('-P', '--port',
    help='M/Monit API REST port. Default: 2813',
    default='2813')
conn_parameters.add_argument('--uri',
    help='M/Monit API REST uri. Default: /Monit',
    default='/Monit')
# Parse arguments:
args = parser.parse_args()
# Assign variables:
monit_url = 'http://' + args.host + ':' + args.port + args.uri
printVerbose("API REST URL: " + monit_url)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#

exit_text = ""
max_error = 0
error_monitors = []
performance = ""
monitor_types = [
    'Process',
    'File',
    'Fifo',
    'Filesystem',
    'Directory',
    'Remote Host',
    'System',
    'Program',
    'Network'
]
status_ok = [
    'OK',
    'Status ok',
    'Initializing',
    'Inicializando'
]
try:
    # Connect to monit API REST and get all data:
    response = requests.get(monit_url, timeout=3.0)
except:
    printVerbose(sys.exc_info())
    exit_text = "UNKNOWN - Error al intentar conectar con la API REST de Monit"
    exit_satus = STATE_UNKNOWN
else:
    printVerbose(response)
    if (response.status_code == requests.codes.ok):
        # Get the data in json format:
        data = response.json()
        # Print version:
        version = data['Version']
        printVerbose("Version: " + version)
        for monitor in data.keys():
            # Monitor could be of different types, check if it is a valid one:
            if monitor in monitor_types:
                printVerbose("Monitor type: " + monitor)
                for process, details in data[monitor].items():
                    printVerbose("Process: " + process)
                    # Check if this monitor is not OK
                    if "status" in details and details['status'] not in status_ok:
                        max_error = max_error + 1
                        error_monitors.append(process + " (" + details['status'] + ")")
                        printVerbose("ERROR: " + process + " (" + details['status'] + ")")
        # Check for errors:
        if max_error > 0:
            exit_text = "WARNING - Los siguientes monitores de M/Monit estan en estado de error: " + ', '.join(error_monitors)
            exit_status = STATE_WARNING
        else:
            exit_text = "OK - Todos los monitores de M/Monit estan en estado OK"
            exit_status = STATE_OK
        performance = "errors=" + str(max_error)
    else:
        exit_text = "UNKNOWN - El servicio API REST de M/Monit no respondio bien: STATUS CODE " + str(response.status_code)
        exit_status = STATE_UNKNOWN

print(exit_text + " | " + performance)
sys.exit(exit_satus)


