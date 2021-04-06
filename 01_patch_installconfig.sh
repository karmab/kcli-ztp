ssh-keyscan -H {{ config_host if config_host != '127.0.0.1' else baremetal_net|local_ip }} >> ~/.ssh/known_hosts
echo -e "Host=*\nStrictHostKeyChecking=no\n" > ~/.ssh/config
{% if not disconnected %}
PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
echo -e "pullSecret: |\n  $PULLSECRET" >> /root/install-config.yaml
{% endif %}
SSHKEY=$(cat /root/.ssh/id_rsa.pub)
echo -e "sshKey: |\n  $SSHKEY" >> /root/install-config.yaml
