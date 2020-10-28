#! /usr/bin/env python
# -*- coding: utf-8 -*-

#
# Check Rocket.Chat Statistics
#

import argparse, sys
import json
from requests import sessions
from pprint import pprint
from rocketchat_API.rocketchat import RocketChat

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Plugin info
#
PLUGIN_AUTHOR = "BBR"
PLUGIN_VERSION = "1.0"
PLUGIN_CONTACT = "soporte@bbr.cl"
PLUGIN_DESCRIPTION = '''
CHECK ROCKET.CHAT STATISTICS PLUGIN
This plugin checks Rocket.Chat server statistics.
'''
PLUGIN_EPILOG = '''
AUTHOR: {author}
CONTACT: {contact}
'''.format(author=PLUGIN_AUTHOR, contact=PLUGIN_CONTACT)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Nagios return codes
#
STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3
exit_satus = STATE_OK

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
    help='Rocket.Chat URL',
    required=True)
group = parser.add_argument_group()
group.add_argument('--user',
    help='Rocket.Chat user to connect')
group.add_argument('--password',
    help='Rocket.Chat user\'s password')
parser.add_argument("--verbose-mode", action="store_true",
    help="Increase output verbosity")
# Parse arguments:
args = parser.parse_args()
printVerbose(args)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Chek stats
#
rocket = RocketChat(args.user, args.password, server_url=args.url)
stats = rocket.statistics().json()
if stats['success']:
    printVerbose("Active Users: " + str(stats['activeUsers']))
    printVerbose("Away Users: " + str(stats['awayUsers']))
    printVerbose("Online Users: " + str(stats['onlineUsers']))
    printVerbose("Total Users: " + str(stats['totalUsers']))
    printVerbose("Total Messages: " + str(stats['totalMessages']))
    printVerbose("Total Rooms: " + str(stats['totalRooms']))
    printVerbose("Total Uploads: " + str(stats['uploadsTotal']))
    printVerbose("Total Uploads Size: " + str(stats['uploadsTotalSize']))
    printVerbose("Rocket.Chat Version: " + str(stats['version']))
    exit_satus = STATE_OK
    exit_message = "OK - STATS: Users: {onlineUsers} online/ {awayUsers} away/ {totalUsers} total, Rooms: {totalRooms}, Messages: {totalMessages}, Uploads: {uploadsTotal}/{uploadsTotalSize}MiB, Version: {version} | online_users={onlineUsers} away_users={awayUsers} total_users={totalUsers} total_rooms={totalRooms} total_messages={totalMessages} total_uploads={uploadsTotal} total_uploads_size={uploadsTotalSize}MiB".format(
        onlineUsers=str(stats['onlineUsers']),
        awayUsers=str(stats['awayUsers']),
        totalUsers=str(stats['totalUsers']),
        totalRooms=str(stats['totalRooms']),
        totalMessages=str(stats['totalMessages']),
        uploadsTotal=str(stats['uploadsTotal']),
        uploadsTotalSize=str(int(stats['uploadsTotalSize'] / 1024 / 1024)),
        version=str(stats['version'])
    )
else:
    exit_satus = STATE_UNKNOWN
    exit_message = "UNKNOWN - Couldn't get stats from server"
# Report:
print(exit_message)
sys.exit(exit_satus)

