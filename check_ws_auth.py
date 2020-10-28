#! /usr/bin/env python
# -*- coding: utf-8 -*-

#
# Check WS Auth Nagios Plugin
#

import argparse, sys
import requests
import json
import base64

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
CHECK WS AUTH PLUGIN
This plugin connects to a WebService and checks if it can login.
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
conn_parameters.add_argument('--url',
    help='WS URL. Example: https://example.net:8773/api/login',
    required=True)
conn_parameters.add_argument('-u', '--user',
    help='User to login',
    required=True)
conn_parameters.add_argument('-p', '--password',
    help='Password of the user',
    required=True)
# Parse arguments:
args = parser.parse_args()
# Assign variables:
printVerbose("WS URL: " + args.url)
printVerbose("User: " + args.user)
printVerbose("Password: " + args.password)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Perform checks
#
body = {
    "username": args.user,
    "password": args.password
}
data = base64.b64encode(bytes(json.dumps(body), 'utf-8'))
printVerbose(data)
response = requests.post(args.url, data = data)
print(response.text)

#print(result['text'] + "|duration=" + str(result['duration']))
#sys.exit(result['status'])


