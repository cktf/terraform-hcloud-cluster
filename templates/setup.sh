#!/bin/bash

# Load interface name
until ip route | head -n 1 | awk '{print $5}'; do sleep 1; done
IFACE=$(ip route | head -n 1 | awk '{print $5}')

# Detect configuration based on network manager
if command -v networkd-dispatcher &>/dev/null; then
CONFIG_FILE="/etc/networkd-dispatcher/routable.d/50-masq"
elif command -v NetworkManager &>/dev/null; then
CONFIG_FILE="/etc/NetworkManager/dispatcher.d/ifup-local"
else
CONFIG_FILE="/etc/network/if-up.d/50-masq"
fi

# Setup configuration based on gateway type
if [[ "${gateway}" == *"/"* ]]; then
cat <<-EOF > $CONFIG_FILE && chmod +x $CONFIG_FILE
#!/bin/bash
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s '${gateway}' -o $IFACE -j MASQUERADE
EOF
elif [[ -n "${gateway}" ]]; then
cat <<-EOF > $CONFIG_FILE && chmod +x $CONFIG_FILE
#!/bin/bash
rm /etc/resolv.conf
echo 'nameserver 185.12.64.1' >> /etc/resolv.conf
echo 'nameserver 185.12.64.2' >> /etc/resolv.conf
sleep 5 && ip route replace default via ${gateway} &
EOF
else
exit 1
fi

# Restart networking services to apply changes
systemctl disable systemd-networkd-wait-online.service || true
systemctl restart networkd-dispatcher.service || true
systemctl restart NetworkManager.service || true
systemctl restart networking.service || true