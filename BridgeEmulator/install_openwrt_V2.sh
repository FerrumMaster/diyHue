curl#!/bin/bash

echo -e "\033[32m	Please check if your device has enough storage, 128MB devices are not not enough. Please use the guide to extend overlay using a USB storage device.
https://openwrt.org/docs/guide-user/additional-software/extroot_configuration
Also use the same guide to enable SWAP file as 128MB of RAM is not enough for the current python3 dependency install adding 128MB is enough. It may change with later versions.\033[0m"

echo -e "\033[32m Updating repository.\033[0m"
opkg update
wait

echo -e "\033[32m Installing dependencies.\033[0m"
opkg install ca-bundle git git-http nano nmap python3 python3-pip python3-setuptools openssl-util curl unzip coap-client kmod-bluetooth bluez-daemon ca-certificates libustream-wolfssl libcurl
wait

echo -e "\033[32m Creating directories.\033[0m"
mkdir -p /opt/tmp
mkdir -p /opt/hue-emulator

echo -e "\033[32m Updating python3-pip.\033[0m"
python3 -m pip install --upgrade pip

echo -e "\033[32m We need some wheels.\033[0m"
pip3 install wheel
wait

echo -e "\033[32m Downloading diyHue.\033[0m"
cd /opt/tmp
git clone https://www.github.com/diyhue/diyHue.git
wait

echo -e "\033[32m Copying files to directories.\033[0m"
cd /opt/tmp/diyHue/BridgeEmulator
cp HueEmulator3.py updater /opt/hue-emulator/
cp -r HueObjects configManager flaskUI functions lights logManager sensors services /opt/hue-emulator/

echo -e "\033[32m Copy web interface files.\033[0m"
curl -sL https://www.github.com/diyhue/diyHueUI/releases/latest/download/DiyHueUI-release.zip -o diyHueUI.zip
wait
unzip -qo diyHueUI.zip
wait
mv index.html /opt/hue-emulator/flaskUI/templates/
cp -r static /opt/hue-emulator/flaskUI/

echo -e "\033[32m Copying custom network function for openwrt.\033[0m"
rm -Rf /opt/hue-emulator/BridgeEmulator/functions/network.py
mv /opt/tmp/diyHue/BridgeEmulator/functions/network_OpenWrt.py /opt/hue-emulator/functions/network.py

echo -e "\033[32m Installing pip dependencies.\033[0m"
python3 -m pip install -r /opt/tmp/diyHue/requirements.txt
wait

echo -e "\033[32m Creating certificate. Here you can change yor default network port if they differ\033[0m"
cd /opt/hue-emulator
mkdir -p /opt/hue-emulator/config
mac=`cat /sys/class/net/br-lan/address`
curl https://raw.githubusercontent.com/mariusmotea/diyHue/9ceed19b4211aa85a90fac9ea6d45cfeb746c9dd/BridgeEmulator/openssl.conf -o openssl.conf
wait
serial="${mac:0:2}${mac:3:2}${mac:6:2}fffe${mac:9:2}${mac:12:2}${mac:15:2}"
dec_serial=`python3 -c "print(int(\"$serial\", 16))"`
openssl req -new -days 3650 -config openssl.conf -nodes -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -pkeyopt ec_param_enc:named_curve -subj "/C=NL/O=Philips Hue/CN=$serial" -keyout private.key -out public.crt -set_serial $dec_serial
wait
touch /opt/hue-emulator/config/cert.pem
cat private.key > /opt/hue-emulator/config/cert.pem
cat public.crt >> /opt/hue-emulator/config/cert.pem
rm private.key public.crt

echo -e "\033[32m Changing permissions.\033[0m"

chmod 755 /opt/hue-emulator/HueEmulator3.py
chmod 755 /opt/hue-emulator/HueObjects
chmod 755 /opt/hue-emulator/configManager
chmod 755 /opt/hue-emulator/flaskUI
chmod 755 /opt/hue-emulator/functions
chmod 755 /opt/hue-emulator/lights
chmod 755 /opt/hue-emulator/logManager
chmod 755 /opt/hue-emulator/sensors
chmod 755 /opt/hue-emulator/services
chmod 755 /opt/hue-emulator/functions/network.py

echo -e "\033[32m Copy startup service.\033[0m"
cd /opt/tmp/diyHue/BridgeEmulator
cp hueemulatorWrt-service /etc/init.d/

echo -e "\033[DELETE NOHUP\033[0m"
nano /etc/init.d/hueemulatorWrt-service

echo -e "\033change <presentationURL>/</presentationURL> \033[0m"
nano /opt/hue-emulator/flaskUI/templates/description.xml


echo -e "\033[32m Enable startup service.\033[0m"
chmod 755 /etc/init.d/hueemulatorWrt-service
/etc/init.d/hueemulatorWrt-service enable

echo -e "\033[32m Cleaning...\033[0m"
cd /opt/hue-emulator
rm -Rf /opt/tmp
wait

echo -e "\033[32m SERVER PORT CHANGE. The Elegant way... I use 66\033[0m"

uci -q delete uhttpd.main.listen_http
uci add_list uhttpd.main.listen_http="0.0.0.0:66"
uci add_list uhttpd.main.listen_http="[::]:66"
uci -q delete uhttpd.main.listen_https
uci add_list uhttpd.main.listen_https="0.0.0.0:8443"
uci add_list uhttpd.main.listen_https="[::]:8443"
uci commit
/etc/init.d/uhttpd restart

echo -e "\033[32m Installation completed.\033[0m"
wait
reboot 10
exit 0
