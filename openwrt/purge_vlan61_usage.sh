#!/bin/bash

#purges records older than 2 months

DATA_DIR=/var/lib/fair_use
DAYS_TO_KEEP=62

for file in $DATA_DIR/*.{input,output}; do
	lines=`wc -l <$file`
	if [ "$lines" -gt $DAYS_TO_KEEP ]; then
		tmpfile=/tmp/$$.tmp
		tail -$DAYS_TO_KEEP <$file >$tmpfile && cp $tmpfile $file
		rm $tmpfile
	fi
done

