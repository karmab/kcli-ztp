set -euo pipefail

yum -y install dnsmasq
cp /root/dnsmasq.conf /etc/dnsmasq.d/custom.conf
systemctl enable --now dnsmasq
