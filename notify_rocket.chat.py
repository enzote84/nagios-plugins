#! /usr/bin/env python
# -*- coding: utf-8 -*-

#
# Notify Rocket.Chat
#

import argparse, sys
import requests
import json

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Plugin info
#
PLUGIN_AUTHOR = "BBR"
PLUGIN_VERSION = "1.0"
PLUGIN_CONTACT = "soporte@bbr.cl"
PLUGIN_DESCRIPTION = '''
NOTIFY ROCKET.CHAT PLUGIN
This plugin send a notification to a Rocket.Chat server webhook.
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
parser.add_argument('--url',
    help='Rocket.Chat Webhook URL',
    required=True)
parser.add_argument('--channel',
    help='Channel to post the message. Default: "alerts"',
    default='#alerts')
group = parser.add_mutually_exclusive_group()
group.add_argument('--host-notification', action="store_true",
    help='Notify a host problem')
group.add_argument('--service-notification', action="store_true",
    help='Notify a service problem')
parser.add_argument('--notificationtype',
    help='Use with macro $NOTIFICATIONTYPE$: ["PROBLEM", "RECOVERY", "ACKNOWLEDGEMENT", "FLAPPINGSTART", "FLAPPINGSTOP", "FLAPPINGDISABLED", "DOWNTIMESTART", "DOWNTIMEEND", "DOWNTIMECANCELLED"]',
    required=True)
parser.add_argument('--hostname',
    help='Use with macro $HOSTNAME$',
    required=True)
parser.add_argument('--hostalias',
    help='Use with macro $HOSTALIAS$')
parser.add_argument('--hostaddress',
    help='Use with macro $HOSTADDRESS$')
parser.add_argument('--hoststate',
    help='Use with macro $HOSTSTATE$: ["UP", "DOWN", "UNREACHABLE"]')
parser.add_argument('--hostoutput',
    help='Use with macro $HOSTOUTPUT$')
parser.add_argument('--hostduration',
    help='Use with macro $HOSTDURATION$: Format is "XXh YYm ZZs", indicating hours, minutes and seconds.')
parser.add_argument('--servicedesc',
    help='Use with macro $SERVICEDESC$')
parser.add_argument('--servicestate',
    help='Use with macro $SERVICESTATE$: ["OK", "WARNING", "UNKNOWN", "CRITICAL"]')
parser.add_argument('--serviceoutput',
    help='Use with macro $SERVICEOUTPUT$')
parser.add_argument('--serviceduration',
    help='Use with macro $SERVICEDURATION$: Format is "XXh YYm ZZs", indicating hours, minutes and seconds.')
parser.add_argument("--verbose-mode", action="store_true",
    help="Increase output verbosity")
# Parse arguments:
args = parser.parse_args()
printVerbose(args)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios variables:
#
# $NOTIFICATIONTYPE$: "PROBLEM", "RECOVERY", "ACKNOWLEDGEMENT", "FLAPPINGSTART", "FLAPPINGSTOP", "FLAPPINGDISABLED", "DOWNTIMESTART", "DOWNTIMEEND", or "DOWNTIMECANCELLED"
# $NOTIFICATIONCOMMENT$
# $HOSTNAME$
# $HOSTALIAS$
# $HOSTSTATE$: "UP", "DOWN", or "UNREACHABLE"
# $HOSTADDRESS$
# $HOSTOUTPUT$
# $HOSTDURATION$: Format is "XXh YYm ZZs", indicating hours, minutes and seconds.
# $SERVICEDESC$
# $SERVICESTATE$: "OK", "WARNING", "UNKNOWN", or "CRITICAL"
# $SERVICEOUTPUT$
# $SERVICEDURATION$: Format is "XXh YYm ZZs", indicating hours, minutes and seconds.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Functions
#
def getColor(state):
    stateToColor = {
        "UP": "green",
        "DOWN": "red",
        "UNREACHABLE": "orange",
        "OK": "green",
        "WARNING": "yellow",
        "UNKNOWN": "grey",
        "CRITICAL": "red"
    }
    return stateToColor[state]

def getEmoji(state):
    stateToEmoji = {
        "UP": ":white_check_mark:",
        "DOWN": ":scream:",
        "UNREACHABLE": ":ghost:",
        "OK": ":ok:",
        "WARNING": ":warning:",
        "UNKNOWN": ":man_shrugging:",
        "CRITICAL": ":exclamation:"
    }
    if (args.notificationtype == "ACKNOWLEDGEMENT"):
        return ":tools:"
    elif (args.notificationtype == "RECOVERY"):
        return ":smiley:"
    else:
        return stateToEmoji[state]

def getHostPayload():
    payload = {
        "channel": args.channel,
        "alias": args.hostname,
        "emoji": getEmoji(args.hoststate),
        "text": "*HOST {notificationtype}* - El host *{hostalias}* (IP: {hostaddress}) está en estado *{hoststate}*".format(**vars(args)),
        "attachments": [{
            "text": args.hostoutput,
            "color": getColor(args.hoststate),
            "fields": [{
                "title": "Tiempo en este estado:",
                "value": args.hostduration
            }]
        }]
    }
    return payload

def getServicePayload():
    payload = {
        "channel": args.channel,
        "alias": args.hostname,
        "emoji": getEmoji(args.servicestate),
        "text": "*SERVICE {notificationtype}* - El servicio *{servicedesc}* está en estado *{servicestate}*".format(**vars(args)),
        "attachments": [{
            "text": args.serviceoutput,
            "color": getColor(args.servicestate),
            "fields": [{
                "title": "Tiempo en este estado:",
                "value": args.serviceduration
            }]
        }]
    }
    return payload

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Send notification
#
if args.host_notification:
    payload = getHostPayload()
elif args.service_notification:
    payload = getServicePayload()
else:
    print("ERROR - Must select --host-notification or --service-notification")
data = json.dumps(payload)
printVerbose(data)
response = requests.post(args.url, data = data)
print(response.text)
