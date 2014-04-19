# pytimesheet

This tool is created to help me figure out my own time spend on various things. It also has a really creative name :)

## Data Format
### Storage
The data format relies mainly on the filesystem to setup a neat structure without any DB shenanigans. Additionally we use ISO-8601 dates everywhere because I like that.

        /path/to/pytimesheet/YYYY/WW/YYYY-MM-DD

In doing this we can keep structured timesheets that anyone can read with any old $EDITOR.
### New files
To create a new timesheet entry simply create a new file for $TODAY

        2014-04-20

With the following format

        08:00 - 09:00 * Uploaded pytimesheet to github

## Reporting
### Daily
To keep an eye on your daily hours

        python pytimesheet.py --report today

### Weekly / Historic
To go back further you can execute a weekly report

        python pytimesheet.py --report week -y 2014 -w 16

Historic reporting can go back somewhat further by cheating with bash

        for i in {1..15}; do python timesheet.py -q y --report week --csv y -y 2014 -w $i; done;

## TODO

1. Fix boolean operators so that passing "-c" will output CSV and not need a full "-c y".
1. Extend support to include create today's timesheet by default rather than exiting. This way you don't need to first lookup for week number
1. Remove the hardcoded dataDir
1. Turn into a web service
1. Add built in reporting to remove manual csv -> libreoffice calc
1. Your issue here...
