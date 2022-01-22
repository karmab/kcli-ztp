cd /root
{% for manifest in 'ztp_spoke_manifests'|find_manifests %}
echo " {{ manifest }} : |" >> ztp_spoke_manifests.yml
sed -e "s/^/  /g" ztp_spoke_manifests/{{ manifest }} >> ztp_spoke_manifests.yml
{% endfor %}
echo -e "\n---" >> ztp_spoke_manifests.yml
