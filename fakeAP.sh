#!/bin/bash

# Function to get the information of the connected Wi-Fi network
function get_wifi_info() {
    # Get the name of the connected Wi-Fi network
    SSID=$(iwgetid -r)
    
    # Get the BSSID (MAC address) of the access point
    BSSID=$(iw dev wlan0 link | grep SSID | awk '{print $2}')
    
    # Get the channel number of the access point
    CHANNEL=$(iw dev wlan0 link | grep channel | awk '{print $2}')
    
    # Get the encryption type of the network
    ENCRYPTION=$(iw dev wlan0 link | grep 'key:on' | awk '{print $3}')
    
    # Return the information as an array
    echo "$SSID $BSSID $CHANNEL $ENCRYPTION"
}

# Get the password from the argument
PASSWORD=$1

# Get the information of the connected Wi-Fi network
WIFI_INFO=($(get_wifi_info))

# Extract the information from the array
SSID=${WIFI_INFO[0]}
BSSID=${WIFI_INFO[1]}
CHANNEL=${WIFI_INFO[2]}
ENCRYPTION=${WIFI_INFO[3]}

# Create the hostapd configuration file
cat > /etc/hostapd/hostapd.conf << EOL
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOL

# Start the network interface in Access Point mode
ifconfig wlan0 192.168.50.1 netmask 255.255.255.0

# Start the DHCP server
service isc-dhcp-server start

# Start hostapd
hostapd /etc/hostapd/hostapd.conf &
