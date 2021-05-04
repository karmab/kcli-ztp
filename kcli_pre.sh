{% if version in ['nightly', 'latest', 'stable'] %}
DOTS=$(echo {{ tag }} | grep -o '\.' | wc -l)
echo $DOTS
[ "$DOTS" -eq "1" ] || (echo tag should be 4.X && exit 1)
{% elif version == 'ci' %}
grep -q registry.ci.openshift.org {{ pullsecret }} || (echo Missing token for registry.ci.openshift.org && exit 1)
{% endif %}
{% if config_host == '127.0.0.1' and not lab %}
ip a l {{ baremetal_net }} >/dev/null 2>&1 || (echo Issue with network {{ baremetal_net }} && exit 1)
{% endif %}
