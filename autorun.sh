#!/bin/bash
cd "$(dirname "$0")"

CONFIGFILE=/etc/lcds-client.conf
# Load configuration
. $CONFIGFILE

AR_LOG=$LOGS/autorun.log
PF_LOG=$LOGS/prefetch.log
TURNMEOFF=~/turnoff_display.tmp

if [ -f $AR_LOG ]
then
  mv $AR_LOG $AR_LOG.1
fi

echo "$(date "+%F %T") : Start" > $AR_LOG

export PATH="/home/pi/bin:$PATH"

# Init network and wait for connectivity
lcds-connectivity.sh INIT &> $AR_LOG

# Continuous slow HTTP checks
lcds-connectivity.sh &

if [ $SQUID -eq 1 ]; then
  export http_proxy="http://localhost:3128"
fi

if [ $PREFETCHER -eq 1 ]; then
  echo "$(date "+%F %T") : Starting prefetcher" >> $AR_LOG
  httpPrefetch &> $PF_LOG &

  # Wait for proper init
  sleep 2
fi

# Move cursor out of the way
xwit -root -warp $( cat /sys/module/*fb*/parameters/fbwidth ) $( cat /sys/module/*fb*/parameters/fbheight )

# Disable DPMS / Screen blanking
xset s off

if [ -f $TURNMEOFF ]
then
  xset dpms force off # Disable X
  tvservice -o # Turn off screen
fi

# rm $TURNMEOFF

while true; do
  if [ -f $TURNMEOFF ]
  then
    if pgrep $BROWSER
    then
      echo "$(date "+%F %T") : Killing $BROWSER now" >> $AR_LOG
      pgrep $VIDEO && kill -9 $(pidof $VIDEO) # Kill player first if necessary
      kill -1 $(pidof $BROWSER) # Kill browser
      xset dpms force off # Disable X
      tvservice -o # Turn off screen
    fi
  else
    if ! pgrep $BROWSER
    then
      echo "$(date "+%F %T") : Start $BROWSER now" >> $AR_LOG
      tvservice -p # Turn on screen
      sleep 5
      xset -dpms
      sleep 5
      $BROWSER "$LCDS/frontend" & # Start browser on frontend
    fi
  fi
  sleep 10
done;
