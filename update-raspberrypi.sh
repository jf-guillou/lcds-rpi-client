#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo rpi-update

# Updater configuration
DISP_USER=pi

CONFIGFILE=/etc/lcds-client.conf
# Load configuration
. $CONFIGFILE

killall lcds-autorun.sh
killall lcds-connectivity.sh
killall $BROWSER
killall $VIDEO
killall httpPrefetch

if [ $SQUID -eq 1 ] ; then
  /bin/systemctl stop squid3
  rm -rf /var/spool/squid3/*
  /usr/sbin/squid3 -Nz
fi

# Kweb updates overwrites configuration
if [ $(grep -c "^omxplayer_in_terminal_for_video = False" /usr/local/bin/kwebhelper_settings.py) -eq 0 ] ; then
echo "
omxplayer_in_terminal_for_video = False
omxplayer_in_terminal_for_audio = False
useAudioplayer = False
useVideoplayer = False
" >> /usr/local/bin/kwebhelper_settings.py
fi

# Squid updates may overwrite configuration
if [ $(grep -c "/etc/squid3/squid.local.conf" /etc/squid3/squid.conf) -eq 0 ] ; then
echo "include /etc/squid3/squid.local.conf" >> /etc/squid3/squid.conf
fi

wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/autorun.sh -O /usr/local/bin/lcds-autorun.sh
chmod a+x /usr/local/bin/lcds-autorun.sh

wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/update-raspberrypi.sh -O /usr/local/bin/lcds-update-raspberrypi.sh
chmod a+x /usr/local/bin/lcds-update-raspberrypi.sh

wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/connectivity.sh -O /usr/local/bin/lcds-connectivity.sh
chmod a+x /usr/local/bin/lcds-connectivity.sh

wget https://github.com/jf-guillou/httpPrefetch/releases/download/v0.1.0/httpPrefetch -O /usr/local/bin/httpPrefetch
chmod a+x /usr/local/bin/httpPrefetch

sudo -u $DISP_USER wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/omxplayer -O /home/$DISP_USER/bin/omxplayer
chmod u+x /home/$DISP_USER/bin/omxplayer

reboot
