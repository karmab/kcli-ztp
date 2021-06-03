{% if baremetal_cidr == None %}
echo baremetal_cidr not set. No network, no party!
exit 1
{% endif %}
{% if version in ['nightly', 'latest', 'stable'] %}
DOTS=$(echo {{ tag }} | grep -o '\.' | wc -l)
[ "$DOTS" -eq "1" ] || (echo tag should be 4.X && exit 1)
{% if version in ['latest', 'stable'] %}
VERSIONCHECK=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/{{ version }}-{{ tag }}/release.txt | grep -q 'Pull from')
[ "$VERSIONCHECK" -eq "0" ] || (echo incorrect mix {{ version }} and {{ tag }} && exit 1)
{% endif %}
{% elif version == 'ci' %}
grep -q registry.ci.openshift.org {{ pullsecret }} || (echo Missing token for registry.ci.openshift.org && exit 1)
{% endif %}
{% if config_host == '127.0.0.1' and not lab %}
ip a l {{ baremetal_net }} >/dev/null 2>&1 || (echo Issue with network {{ baremetal_net }} && exit 1)
{% endif %}
