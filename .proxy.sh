echo "proxy={{ 'http://' + http_proxy if 'http' not in http_proxy else http_proxy }}" >> /etc/dnf/dnf.conf
while true ; do
  IP=$(ip -o addr show {{ installer_nic }} |head -1 | awk '{print $4}' | cut -d'/' -f1)
  echo $IP | grep -q '\.' && break
  sleep 5
done
sed -i "s@noProxy: {{ baremetal_cidr }}@noProxy: $IP,{{ api_ip }},.{{ cluster }}.{{ domain }}@" /root/install-config.yaml
sed -i "s@NO_PROXY={{ baremetal_cidr }}@NO_PROXY=$IP,{{ api_ip }},.{{ cluster }}.{{ domain }}@" /etc/profile.d/proxy.sh
