set -euo pipefail

dnf -y install dnsmasq
cp /root/dnsmasq.conf /etc/dnsmasq.d/custom.conf
systemctl enable --now dnsmasq

cp /etc/resolv.conf /etc/resolv.conf.ori
echo nameserver {{ installer_ip }} > /etc/resolv.conf
