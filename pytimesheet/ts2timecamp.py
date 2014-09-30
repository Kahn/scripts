#!/usr/bin/env python
#
# Publish timesheet entries to timecamp
#
# Parses using the following formats
# HH:MM - HH:MM * Task name - Task desc
# HH:MM - HH:MM * Unallocated task desc
# HH:MM - HH:MM * #Ticketnumber - Task desc

import logging

logger = logging.getLogger('ts2timecamp')
logger.setLevel(logging.DEBUG)
# create file handler which logs even debug messages
fh = logging.FileHandler('ts2timecamp.log')
fh.setLevel(logging.DEBUG)
# create console handler with a higher log level
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
# create formatter and add it to the handlers
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
fh.setFormatter(formatter)
ch.setFormatter(formatter)
# add the handlers to the logger
logger.addHandler(fh)
logger.addHandler(ch)

try:
    import os
    import sys
    import pyinotify
    import datetime
    import time
    import json
    import requests
    import re
    import argparse
#    from pysed import replace, append, lines
    from pprint import pprint
except:
    print "Unexpected error:", sys.exc_info()[0]
    raise

logger.debug('Started ts2timecamp')

parser = argparse.ArgumentParser()
#parser.add_argument("-k", "--key", help="Timecamp API key",action="store_true")
parser.add_argument("key")
args = parser.parse_args()

if not args.key:
  logger.critical('No API key provided!')
  sys.exit(1)

# Timecamp API
apikey = args.key

# Test a request to validate the API
try:
    r = requests.get('https://www.timecamp.com/third_party/api/tasks/format/json/api_token/'+apikey)
except:
    print "Unexpected error:", sys.exc_info()[0]
    raise
logger.debug('Initial logon return code: {0}'.format(r.status_code))
if r.status_code is not 200:
  logger.error('Failed to query timecamp API: {0}'.format(r.text))


# Create date variables
today = datetime.date.today()
isoCalendar = today.isocalendar()
currentYearNumber = str(isoCalendar[0])
currentWeekNumber = str(isoCalendar[1])

dataDir = "."
currentWeekDir = dataDir+'/'+currentYearNumber+'/'+currentWeekNumber
currentDayFile = currentWeekDir+'/'+today.isoformat()


def timecampTaskID(taskname):
  '''Creates or returns an existing timecamp task ID'''

  try:
      r = requests.get('https://www.timecamp.com/third_party/api/tasks/format/json/api_token/'+apikey)
  except:
      print "Unexpected error:", sys.exc_info()[0]
      raise

  # Get result in json
  j = r.json()

  # Iterate tasks
  timecampTaskID = False
  for task in j:
    if j[task]['name'] == taskname:
      logger.debug('Matched taskname: %s' % j[task])
      timecampTaskID = j[task]

  if timecampTaskID == False:
    payload = {'name': taskname, 'keywords': 'ts2timecamp', 'parent_id': 0}
    try:
        r = requests.post('https://www.timecamp.com/third_party/api/tasks/format/json/api_token/'+apikey, data=payload)
    except:
        print "Unexpected error:", sys.exc_info()[0]
        raise

  # Repeat our request for the newly created task
  try:
      r = requests.get('https://www.timecamp.com/third_party/api/tasks/format/json/api_token/'+apikey)
  except:
      print "Unexpected error:", sys.exc_info()[0]
      raise

  # Get result in json
  j = r.json()

  # Iterate tasks
  timecampTaskID = False
  for task in j:
    if j[task]['name'] == taskname:
      logger.debug('Matched taskname: %s' % j[task]['task_id'])
      timecampTaskID = j[task]['task_id']

  logger.debug('timecampTask returns ID: %s' % timecampTaskID)
  return timecampTaskID

def timecampTimeEntry(content, date):
  '''Parse lines and return timecamp time_entry dict'''
  logger.debug('parseLine content: %s' % content)
  match = re.match(r'(.*) - (.*) \* (.*)', content, re.M|re.I)
  try:
    start = time.strptime(match.group(1)+":00", '%H:%M:%S')
    stop = time.strptime(match.group(2)+":00", '%H:%M:%S')
  except AttributeError:
      return False
  except ValueError:
      logger.info('Ignored line: {0}'.format(content))
      return False
  except:
    print "Unexpected error:", sys.exc_info()[0]
    raise
  # Change datetime objects to strings for timecamp
  start_epoch = time.mktime(start)
  stop_epoch = time.mktime(stop)
  start = time.strftime('%H:%M:%S',start)
  stop = time.strftime('%H:%M:%S',stop)
  logger.debug('Start: {0}'.format(start))
  logger.debug('Stop: {0}'.format(stop))
  duration = int((stop_epoch - start_epoch))
  logger.debug('Duration totals {0} seconds'.format(duration))

  # Check for task names
  taskmatch = re.match(r'((?!#).*) - (.*)$', match.group(3), re.M|re.I)
  logger.debug('taskmatch: %s' % taskmatch)
  if taskmatch:
    # Get timecamp task_id
    taskid = timecampTaskID(taskmatch.group(1))

  # Check for ticket numbers
  ticketmatch = re.match(r'(#.*) - (.*)$', match.group(3), re.M|re.I)
  logger.debug('ticketmatch: %s' % ticketmatch)
  if ticketmatch:
    # Get timecamp task_id
    taskid = timecampTaskID(ticketmatch.group(1))

  # Failthrough to BAU
  baumatch = re.match(r'(?!.* - )(.*)$', match.group(3), re.M|re.I)
  logger.debug('baumatch: %s' % baumatch)
  if baumatch:
    # Get timecamp task_id
    taskid = timecampTaskID('BAU')

  logger.debug('taskID: %s' % taskid)

  # Create time entry payloads
  if taskmatch:
    payload = {'task_id':taskid,'duration': duration,'date':date,'note':taskmatch.group(2),'start_time':start,'end_time':stop}
  if ticketmatch:
    payload = {'task_id': taskid, 'duration': duration, 'date': date, 'note': ticketmatch.group(2), 'start_time': start, 'end_time': stop}
  if baumatch:
    payload = {'task_id': taskid, 'duration': duration, 'date': date, 'note': baumatch.group(1), 'start_time': start, 'end_time': stop}

  try:
      r = requests.post('https://www.timecamp.com/third_party/api/time_entry/format/json/api_token/'+apikey, data=payload)
  except:
      print "Unexpected error:", sys.exc_info()[0]
      raise

  j = r.json()

  logger.debug('Time entry payload: %s' % payload)
  logger.debug('Time entry response code: %s' % r.status_code)
  logger.debug('Time entry response: %s' % j['entry_id'])

  return str(j['entry_id'])

# Start inotify loop

wm = pyinotify.WatchManager()  # Watch Manager
mask = pyinotify.IN_CLOSE_WRITE # watched events

class EventHandler(pyinotify.ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        match = re.match('.*((\d{4})[/.-](\d{2})[/.-](\d{2}))$', event.pathname)
        if not match:
            logger.info('Invalid filename: %s' % event.pathname)
            return 1

        timecamp_date = match.group(1)

        try:
            file = open(event.pathname,'r')
        except:
          print "Unexpected error:", sys.exc_info()[0]
          raise

        # Buffer file content
        logger.info('Opened file: {0}'.format(event.pathname))
        data = file.readlines()
        file.close()

        # Reopen file for overwriting
        try:
            file = open(event.pathname+'.tmp','w')
        except:
          print "Unexpected error:", sys.exc_info()[0]
          raise
        
        for line in data:
          entry = timecampTimeEntry(line,timecamp_date)
          if entry:
            logger.debug('Updated line: {0}'.format(entry+'|'+line))
            file.write(entry+'|'+line)
          else:
            logger.debug('Existing line preseved: {0}'.format(line))
            file.write(line)
        file.close()
        os.rename(event.pathname+'.tmp',event.pathname)

handler = EventHandler()
notifier = pyinotify.Notifier(wm, handler)
wdd = wm.add_watch(currentWeekDir, mask, rec=True)

notifier.loop()
