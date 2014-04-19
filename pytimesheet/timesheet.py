#!/usr/bin/env python

# Intention is to turn this into a data storage function for a timesheet webapp
#
# Data stored such as /username/year/weeknumber/yyyy-mm-dd and inherits
# ISO8601 dates via python datetime
#
# Data structure within the daynumber file is 
#   HH:MM - HH:MM * Desc
#   HH:MM - HH:MM * Desc
#
# This notation is because the author has always written timesheets by hand
# this way and is probably inferior to yaml or any other structured text

from __future__ import division
import os
import sys
import re
import time
import datetime
import argparse
import glob

# Setup args
parser = argparse.ArgumentParser(description='Process timesheet files')
parser.add_argument('--report', dest='report', help='Reporting period - today|week')
parser.add_argument('-c','--csv', dest='reportCsv', default='n', help='Output in CSV - n/y')
parser.add_argument('-y','--year', dest='reportYear', help='Sets weekly reporting year')
parser.add_argument('-w','--week', dest='reportWeek', help='Sets weekly reporting week')
parser.add_argument('-q', dest='quiet', default='n', help='Quiet - Dont output errors')
args = parser.parse_args()

# Create date variables
today = datetime.date.today()
isoCalendar = today.isocalendar()
currentYearNumber = str(isoCalendar[0])
currentWeekNumber = str(isoCalendar[1])
#currentDayNumber = str(isoCalendar[2])

# Create storage related variables
dataDir = "/path/to/pytimesheet"
currentWeekDir = dataDir+'/'+currentYearNumber+'/'+currentWeekNumber
currentDayFile = currentWeekDir+'/'+today.isoformat()

def parseLine(content,args):
  '''Parse text format and return time delta in minutes'''
  match = re.match(r'(.*) - (.*) \* (.*)', content, re.M|re.I)
  #print match.group(1)
  #print match.group(2)
  #workItem = timeSpent(match.group(1),match.group(2))
  try:
    struct_time1 = time.strptime(match.group(1), '%H:%M')
    struct_time2 = time.strptime(match.group(2), '%H:%M')
  except AttributeError:
    if args.quiet == 'n':
      print 'Malformed data passed in: %s' % content
      print 'IGNORING!'
      return 0
    else:
      return 0
  except:
    print "Unexpected error:", sys.exc_info()[0]
    raise
  since_epoch1 = time.mktime(struct_time1)
  since_epoch2 = time.mktime(struct_time2)
  timeSpent = int((since_epoch2 - since_epoch1) / 60)
  return timeSpent

# Check for report period or die
if args.report == 'today':
  # Setup the week directory
  if not os.path.exists(currentWeekDir):
    print "No directory: %s" % currentWeekDir
    os._exit(1)
  # Try to open current day
  try:
    file = open(currentDayFile,'r')
  except:
    print "Unexpected error:", sys.exc_info()[0]
    raise
  # Initialise a counter for total time today
  timeSpentToday = 0
  for line in file:
    timeSpentToday = (timeSpentToday + parseLine(line,args))
  file.close()
  # Use integer devision
  totalHours = round(timeSpentToday / 60, 2)
  print 'Hours for day '+today.isoformat()+': '+str(totalHours)
  os._exit(0)
elif args.report == 'week':
  #if args.reportCsv == 'y':
    #print 'year,week,totalHours'
  if not args.reportYear:
    reportYearNumber = currentYearNumber
  else:
    reportYearNumber = args.reportYear
  if not args.reportWeek:
    reportWeekNumber = currentWeekNumber
  else:
    reportWeekNumber = args.reportWeek

  reportWeekDir = dataDir+'/'+reportYearNumber+'/'+reportWeekNumber
  # Setup the week directory
  if not os.path.exists(reportWeekDir):
    print "No directory: %s" % reportWeekDir
    os._exit(1)
    #os.makedirs(weekDir)
  files = glob.glob(reportWeekDir+'/*')
  # Initialise a counter for total time
  timeSpentWeek = 0
  for f in files:
    try:
      day = open(f,'r')
    except:
      print "Unexpected error:", sys.exc_info()[0]
      raise
    for line in day:
      timeSpentWeek = (timeSpentWeek + parseLine(line,args))
    day.close()

  # Use integer devision
  totalHours = round(timeSpentWeek / 60, 2)
  if args.reportCsv == 'y':
    print reportYearNumber+','+reportWeekNumber+','+str(totalHours)
  else:
    print 'Hours for year '+reportYearNumber+' week '+reportWeekNumber+': '+str(totalHours)
  os._exit(0)
else:
  print "No report set, exiting..."
  os._exit(1)
