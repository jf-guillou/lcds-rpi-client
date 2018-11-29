# lcds-rpi-client

The whole project was based on the idea that a proper digital signage could be handled with Raspberry Pi only.

The server part can also be handled by a Raspberry Pi, there isn't much performance required for this CMS.

The client part requires a little more configuration due to the wonky video hardware acceleration on these type of chips.

### Client installation

I recommend using [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/), a console-based OS with minimal dependencies : [direct download](https://downloads.raspberrypi.org/raspbian_lite_latest).
Since we're going to install our own lightweight desktop environment, this is the most optimal solution, although it'll be a long install process.
The latest tested version is Stretch, but anything will work with some dependencies updates.

- Burn this image on a 4Gb or more µSD card using the [appropriate tool](https://www.raspberrypi.org/documentation/installation/installing-images/README.md)
- Connect RPi to a screen and network (DHCP)
- Login by SSH using root / raspberry
- Do not forget to change root password with
  `passwd`
- Extend the partition to fill SD card
  - Automatically : `apt update && apt install -y raspi-config && raspi-config nonint do_expand_rootfs && reboot`
  - Manually : https://elinux.org/RPi_Resize_Flash_Partitions

### Auto-Configuration

Configuration of the Raspberry Pi can be mostly automated, beside some prompts for specific details :

`wget "https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/install-raspberrypi.sh" -O - | bash -s -`

This will install everything and configure most options at the beginning. This whole installation can take an hour.

Please also note that by default, the screen will shutdown at 6pm and reboot at 7am every weekday.
This can be modified by editing the cron file [/etc/cron.d/display_manager](https://help.ubuntu.com/community/CronHowto#Two_Other_Types_of_Crontab).

### Manual Configuration

**In case you don't trust an automatic installer**

Below are the complete explanations for the commands used in the auto-install script :

- Packages installation
```bash
apt update
apt upgrade -y
apt install -y apt-utils raspi-config
apt install -y keyboard-configuration console-data
apt install -y rpi-update nano sudo lightdm spectrwm xwit xserver-xorg python python-tk lxterminal
```

- Configure OS
```bash
raspi-config nonint do_memory_split 128
raspi-config nonint do_change_timezone
raspi-config nonint do_overscan 1
```

- Change root password
```bash
passwd
```

- Create autostart user & set its password
```bash
DISP_USER=pi
LOGS="/home/$DISP_USER/logs"
useradd -m -s /bin/bash -G sudo -G video $DISP_USER
passwd $DISP_USER
sudo -u $DISP_USER mkdir $LOGS
```

- Install browser
```bash
wget http://steinerdatenbank.de/software/kweb-1.7.9.8.tar.gz
tar -xzf kweb-1.7.9.8.tar.gz
cd kweb-1.7.9.8
./debinstall
```

- Configure display
```bash
# Light DM autologin on user
sed -i s/#autologin-user=/autologin-user=$DISP_USER/ /etc/lightdm/lightdm.conf

# Spectrwm autostart script
echo "
disable_border        = 1
bar_enabled           = 0
autorun               = ws[1]:/home/$DISP_USER/autorun.sh
" > /home/$DISP_USER/.spectrwm.conf
chown $DISP_USER: /home/$DISP_USER/.spectrwm.conf
```

- Setup scripts
```bash
# Configuration
LCDS=$(whiptail --inputbox "Please input your webserver address (ie: 'https://lcds-webserver')" 0 0 --nocancel 3>&1 1>&2 2>&3)
CONFIG=$(whiptail --title "Configuration" --separate-output --checklist "Select configuration options" 0 0 0 \
  "WIFI" "Install wifi modules" OFF \
  "SQUID" "Use internal Squid caching proxy (Recommended)" ON \
  "PREFETCHER" "Use internal prefectcher instead of XHR (Recommended)" ON 3>&1 1>&2 2>&3)
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

echo "#!/bin/bash
# Logs storage
export LOGS=\"$LOGS\"

# Enable Squid
export SQUID=$SQUID # 1 or 0

# Enable Wifi
export WIFI=$WIFI # 1 or 0

# Use prefetcher
export PREFETCHER=$PREFETCHER # 1 or 0

# Brower for kiosk mode
export BROWSER=\"kweb3\"

# Video player binaries. Should not be modified
export VIDEO=\"omxplayer.bin\"

# Frontend
export LCDS=\"$LCDS\"
" > /home/$DISP_USER/config.sh
chown $DISP_USER: /home/$DISP_USER/config.sh
chmod u+x /home/$DISP_USER/config.sh

# Load configuration
. /home/$DISP_USER/config.sh

# Scripts
sudo -u $DISP_USER wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/autorun.sh -O /home/$DISP_USER/autorun.sh
chmod u+x /home/$DISP_USER/autorun.sh

sudo -u $DISP_USER wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/update-raspberrypi.sh -O /home/$DISP_USER/update-raspberrypi.sh
chmod u+x /home/$DISP_USER/update-raspberrypi.sh

sudo -u $DISP_USER mkdir /home/$DISP_USER/bin

sudo -u $DISP_USER wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/connectivity.sh -O /home/$DISP_USER/bin/connectivity.sh
chmod u+x /home/$DISP_USER/bin/connectivity.sh
```

- Configure browser in kiosk mode
```bash
echo "-JEKR+-zbhrqfpoklgtjneduwxyavcsmi#?!.," > /home/$DISP_USER/.kweb.conf

chown $DISP_USER: /home/$DISP_USER/.kweb.conf
```

- Configure media player
```bash
echo "
omxplayer_in_terminal_for_video = False
omxplayer_in_terminal_for_audio = False
useAudioplayer = False
useVideoplayer = False
" >> /usr/local/bin/kwebhelper_settings.py

sudo -u $DISP_USER wget https://raw.githubusercontent.com/jf-guillou/lcds-rpi-client/master/omxplayer -O /home/$DISP_USER/bin/omxplayer
chmod u+x /home/$DISP_USER/bin/omxplayer
```

- Configure local proxy
```bash
if [ $SQUID -eq 1 ] ; then
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

strip_query_terms off
range_offset_limit none

error_directory /usr/share/squid3/errors/force_reload
" > /etc/squid3/squid.local.conf
echo "include /etc/squid3/squid.local.conf" >> /etc/squid3/squid.conf
mkdir /usr/share/squid3/errors/force_reload
echo "<html><head></head><body style=\"background-color: black; color: gray;\">
%c - %U
<script type=\"text/javascript\">window.onload = function() {setTimeout(function() {window.location.reload();}, 10000);};</script>
</body></html>
" > /usr/share/squid3/errors/force_reload/generic
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_CONNECT_FAIL
ln -s /usr/share/squid3/errors/force_reload/generic /usr/share/squid3/errors/force_reload/ERR_DNS_FAIL
fi
```

- Configure Prefetcher
```bash
sudo -u $DISP_USER wget https://github.com/jf-guillou/httpPrefetch/releases/download/v0.1.0/httpPrefetch -O /home/$DISP_USER/bin/httpPrefetch
chmod u+x /home/$DISP_USER/bin/httpPrefetch
```

- Configure Wifi
```bash
if [ $WIFI -eq 1 ] ; then
apt install -y firmware-brcm80211 pi-bluetooth wpasupplicant

SSID=$(whiptail --inputbox "Please input your wifi SSID" 8 0 --nocancel 3>&1 1>&2 2>&3)
PSK=$(whiptail --passwordbox "Please input your wifi password" 8 0 --nocancel 3>&1 1>&2 2>&3)

echo "ctrl_interface=/run/wpa_supplicant
update_config=1

" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
wpa_passphrase "$SSID" "$PSK" >> /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
echo "
auto wlan0
allow-hotplug wlan0
iface wlan0 inet manual" >> /etc/network/interfaces
sed -i s/iface\ eth0\ inet\ dhcp/iface\ eth0\ inet\ manual/ /etc/network/interfaces
fi
```

- Configure auto shutdown
```bash
echo "0 18 * * 1-5 $DISP_USER touch /tmp/turnoff_display >> $LOGS/autorun.log 2>&1
0 7  * * 1-5 $DISP_USER /usr/bin/sudo /sbin/reboot >> $LOGS/autorun.log 2>&1
" > /etc/cron.d/display_manager
```
This will make the screen black after 6pm and reboot the pi at 7am.
The reboot is not mandatory, but helps a lot with the general wonkyness of the RPi.

- Firmware update
```bash
rpi-update && reboot
```

- Ready

The browser should start, register with lcds server and display the authorization screen.
