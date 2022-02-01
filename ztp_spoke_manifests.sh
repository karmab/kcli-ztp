{% set spoke = ztp_spokes[index] %}
{% set spoke_name = spoke.name %}

{% for manifest in 'manifests'|find_manifests %}
echo " {{ manifest }} : |" >> manifests.yml
sed -e "s/^/  /g" manifests/{{ manifest }} >> manifests.yml
{% endfor %}
echo -e "\n---" >> manifests.yml
