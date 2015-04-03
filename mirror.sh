#!/usr/bin/env bash

# mirror.sh - Ghetto mirror script for when there is no rsync or better alternatives
# Copyright (C) 2015 Sam Wilson

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# No uninitialised vars
set -u
# Bail on non zero exits
set -o errexit

DATE=`date --utc +%FT%TZ`
OUTPUTDIR=/var/www/pub
# Space seperated list of URLs
TARGETS=(https://example.org/repo/)

for target in "${TARGETS[@]}";
do
  :
  DOMAIN=`echo $target | cut -d "/" -f 3`
  wget -r -c -N -np -q --user-agent="mirror.sh - http://repo.cycloptivity.net/README" --reject "index.html*","robots.txt" -D $DOMAIN $target -P $OUTPUTDIR
  # Calculate date post download not prior
  DATE=`date --utc +%FT%TZ`
  if [ -e $OUTPUTDIR/$DOMAIN/TIMESTAMP ]
  then  
    rm $OUTPUTDIR/$DOMAIN/TIMESTAMP
  fi
  if [ -e $OUTPUTDIR/$DOMAIN/robots.txt ]
  then
    rm $OUTPUTDIR/$DOMAIN/robots.txt
  fi

  echo $DATE > $OUTPUTDIR/$DOMAIN/TIMESTAMP
  echo "Mirror completed: $DOMAIN at $DATE" | logger
done
