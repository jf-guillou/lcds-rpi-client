#!/bin/bash
LCDS=$(whiptail --inputbox "Please input your webserver address (ie: 'https://lcds-webserver')" 0 0 --nocancel 3>&1 1>&2 2>&3)
CONFIG=$(whiptail --title "Configuration" --separate-output --checklist "Select configuration options" 0 0 0 \
  "WIFI" "Install wifi modules" OFF \
  "SQUID" "Use internal Squid caching proxy (Recommended)" ON \
  "PREFETCHER" "Use internal prefetcher instead of XHR (Recommended)" ON 3>&1 1>&2 2>&3)
WIFI=0
SQUID=0
PREFETCHER=0
for c in $CONFIG ; do
  case $c in
    "WIFI") WIFI=1 ;;
    "SQUID") SQUID=1 ;;
    "PREFETCHER") PREFETCHER=1 ;;
    *) ;;
  esac
done

if [ $WIFI -eq 1 ] ; then
  whiptail --title "Wifi information" --msgbox "Using Wifi for a display signage is not recommanded. You may need to add configuration manually by editing the /etc/wpa_supplicant/wpa_supplicant-wlan0.conf file" 0 0 3>&1 1>&2 2>&3
  SSID=$(whiptail --inputbox "Please input your wifi SSID" 8 0 --nocancel 3>&1 1>&2 2>&3)
  PSK=$(whiptail --passwordbox "Please input your wifi password" 8 0 --nocancel 3>&1 1>&2 2>&3)
fi

# Installer configuration
DISP_USER=pi
LOGS=/var/log/lcds-client/
CONFIGFILE=/etc/lcds-client.conf

whiptail --title "SECURITY WARNING" --msgbox "Remember to change root password with 'passwd' AND $DISP_USER password with 'passwd $DISP_USER' commands" 0 0 3>&1 1>&2 2>&3

echo "Install and update packages"
apt update
apt install -y apt-utils raspi-config 
raspi-config nonint do_memory_split 128
raspi-config nonint do_change_timezone
raspi-config nonint do_overscan 1
apt install -y keyboard-configuration console-data
apt upgrade -y
apt install -y rpi-update nano sudo lightdm spectrwm xserver-xorg xwit python python-tk lxterminal

echo "Create autorun user"
if [[ -d /home/$DISP_USER ]] ; then
  usermod -s /bin/bash -G sudo -G video $DISP_USER
else
  useradd -m -s /bin/bash -G sudo -G video $DISP_USER
fi

echo "Prepare logs"
mkdir $LOGS
chown $DISP_USER $LOGS

echo "Install browser"
cd ~
wget http://steinerdatenbank.de/software/kweb-1.7.9.8.tar.gz
tar -xzf kweb-1.7.9.8.tar.gz
cd kweb-1.7.9.8
./debinstall

echo "Configure display"
sed -i s/#autologin-user=/autologin-user=$DISP_USER/ /etc/lightdm/lightdm.conf
echo "
disable_border        = 1
bar_enabled           = 0
autorun               = ws[1]:/usr/local/bin/lcds-autorun.sh
" > /home/$DISP_USER/.spectrwm.conf
chown $DISP_USER: /home/$DISP_USER/.spectrwm.conf

echo "Write configuration"
echo "# Configuration file for lcds-client
# Logs storage
export LOGS=\"$LOGS\"

# Enable Squid
export SQUID=$SQUID # 1 or 0

# Enable Wifi
export WIFI=$WIFI # 1 or 0

# Use prefetcher
export PREFETCHER=$PREFETCHER # 1 or 0

# Brower for kiosk mode
export BROWSER=\"kweb\"

# Video player binaries. Should not be modified
export VIDEO=\"omxplayer.bin\"

# Frontend
export LCDS=\"$LCDS\"
" > $CONFIGFILE

echo "Setup scripts"
wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/autorun.sh -O /usr/local/bin/lcds-autorun.sh
chmod a+x /usr/local/bin/lcds-autorun.sh

wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/update-raspberrypi.sh -O /usr/local/bin/lcds-update-raspberrypi.sh
chmod a+x /usr/local/bin/lcds-update-raspberrypi.sh

wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/connectivity.sh -O /usr/local/bin/lcds-connectivity.sh
chmod a+x /usr/local/bin/lcds-connectivity.sh

echo "Configure browser in kiosk mode"
echo "-JEKR+-zbhrqfpoklgtjneduwxyavcsmi#?!.," > /home/$DISP_USER/.kweb.conf
chown $DISP_USER: /home/$DISP_USER/.kweb.conf

echo "Configure media player"
if [ $(grep -c "^omxplayer_in_terminal_for_video = False" /usr/local/bin/kwebhelper_settings.py) -eq 0 ] ; then
echo "
omxplayer_in_terminal_for_video = False
omxplayer_in_terminal_for_audio = False
useAudioplayer = False
useVideoplayer = False
" >> /usr/local/bin/kwebhelper_settings.py
fi

sudo -u $DISP_USER mkdir /home/$DISP_USER/bin/
sudo -u $DISP_USER wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/omxplayer -O /home/$DISP_USER/bin/omxplayer
chmod u+x /home/$DISP_USER/bin/omxplayer

if [ $SQUID -eq 1 ] ; then
echo "Configure local proxy"
apt install -y squid3
echo "http_port 127.0.0.1:3128

acl localhost src 127.0.0.1

http_access allow localhost
http_access deny all

cache_dir aufs /var/spool/squid3 1024 16 256
maximum_object_size 256 MB

cache_store_log /var/log/squid3/store.log
read_ahead_gap 1 MB

refresh_pattern -i (\.mp4|\.jpg|\.jpeg) 43200 100% 129600 reload-into-ims

request_timeout 30 minutes

strip_query_terms off
range_offset_limit none

error_directory /usr/share/squid3/errors/force_reload
" > /etc/squid3/squid.local.conf
if [ $(grep -c "/etc/squid3/squid.local.conf" /etc/squid3/squid.conf) -eq 0 ] ; then
echo "include /etc/squid3/squid.local.conf" >> /etc/squid3/squid.conf
fi
mkdir /usr/share/squid3/errors/force_reload
echo "<html><head></head><body style=\"background-color: black; color: gray;\">
%c - %U
<script type=\"text/javascript\">window.onload = function() {setTimeout(function() {window.location.reload();}, 10000);};</script>
</body></html>
" > /usr/share/squid3/errors/force_reload/generic
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_CONNECT_FAIL
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_DNS_FAIL
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_READ_ERROR
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_READ_TIMEOUT
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_SOCKET_FAILURE
fi

echo "Configure prefetcher"
wget https://github.com/jf-guillou/httpPrefetch/releases/download/v0.1.0/httpPrefetch -O /usr/local/bin/httpPrefetch
chmod a+x /usr/local/bin/httpPrefetch

if [ $WIFI -eq 1 ] ; then
echo "Configure WIFI"
apt install -y firmware-brcm80211 pi-bluetooth wpasupplicant
echo "ctrl_interface=/run/wpa_supplicant
update_config=1

" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
wpa_passphrase "$SSID" "$PSK" >> /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
echo "auto wlan0
allow-hotplug wlan0
iface wlan0 inet dhcp" > /etc/network/interfaces.d/wlan0
fi

echo "Configure auto-shutdown"
echo "0 18 * * 1-5 $DISP_USER touch /home/$DISP_USER/turnoff_display.tmp >> $LOGS/autorun.log 2>&1
0 7  * * 1-5 $DISP_USER rm /home/$DISP_USER/turnoff_display.tmp && /usr/bin/sudo /sbin/reboot >> $LOGS/autorun.log 2>&1
" > /etc/cron.d/display_manager

echo "Firmware update. This will reboot the raspberry pi!"
rpi-update && reboot
