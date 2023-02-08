#!/bin/bash

# Check if the user is root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

systemctl unmask hostapd.service
systemctl restart hostapd.service
systemctl status hostapd.service

# Stop the network manager
systemctl stop NetworkManager

# Create a new network interface
cat > /etc/network/interfaces << EOL
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The main network interface
allow-hotplug wlan0
iface wlan0 inet static
    address 10.0.0.1
    netmask 255.255.255.0
    network 10.0.0.0
    broadcast 10.0.0.255
EOL

# Configure the DHCP server (dnsmasq)
cat > /etc/dnsmasq.conf << EOL
interface=wlan0
dhcp-range=10.0.0.10,10.0.0.100,255.255.255.0,24h
EOL

# Configure the access point (hostapd)
cat > /etc/hostapd/hostapd.conf << EOL
interface=wlan0
hw_mode=g
channel=7
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=your_password
ssid=Your_SSID
EOL

# Update the hostapd configuration file path
sed -i 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' /etc/default/hostapd

# Start the services
systemctl start hostapd
systemctl start dnsmasq

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Configure iptables
iptables --table nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Save the iptables rules
iptables-save > /etc/iptables.ipv4.nat

# Update the iptables rules on boot
cat > /etc/network/if-pre-up.d/iptables << EOL
#!/bin/sh
iptables-restore < /etc/iptables.ipv4.nat
EOL
chmod +x /etc/network/if-pre-up.d/iptables

# Restart the services
systemctl restart hostapd
systemctl restart dnsmasq

# Done
echo "Access point created successfully"
