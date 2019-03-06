#!/bin/bash

if [ $# -gt 0 ] ; then

  INT=eth0

  if [ $WIFI -eq 1 ] ; then
    INT=wlan0

    echo "$(date "+%F %T") [$INT] : Start supplicant"
    /usr/bin/sudo /sbin/wpa_supplicant -B -i $INT -c /etc/wpa_supplicant/wpa_supplicant-$INT.conf
    sleep 6

    echo "$(date "+%F %T") [$INT] : Wait for connection to SSID"
    fails=0
    while [[ $(/usr/bin/sudo /sbin/wpa_cli -i $INT status | grep -c "wpa_state=COMPLETED") -eq 0 ]]
    do
      sleep 10
      ((fails++))
      if [[ $fails -gt 12 ]] ; then
        /usr/bin/sudo reboot
      fi
    done
  fi

  echo "$(date "+%F %T") [$INT] : Wait for IP address"
  fails=0
  while [[ $(/usr/bin/sudo /sbin/ifconfig $INT | grep -c "inet .* scope global") -eq 0 ]]
  do
    sleep 10
    ((fails++))
    if [[ $fails -gt 12 ]] ; then
      /usr/bin/sudo reboot
    fi
  done

  echo "$(date "+%F %T") [$INT] : Wait for curl success on web frontend"
  fails=0
  while ! curl -s $LCDS --connect-timeout 3 > /dev/null
  do
    sleep 10
    ((fails++))
    if [[ $fails -gt 12 ]] ; then
      /usr/bin/sudo reboot
    fi
  done

  echo "$(date "+%F %T") [$INT] : Good to go"
else

  while true
  do

    fails=0
    while ! curl -s $LCDS --connect-timeout 3 > /dev/null
    do
      sleep 10
      ((fails++))
      if [[ $fails -gt 12 ]] ; then
        /usr/bin/sudo reboot
      fi
    done

    sleep 60
  done
fi
