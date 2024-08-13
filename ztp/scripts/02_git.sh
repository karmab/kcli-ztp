PRIMARY_NIC=$(ls -1 /sys/class/net | grep -v podman | head -1)
export IP=$(ip -o addr show $PRIMARY_NIC | head -1 | awk '{print $4}' | cut -d'/' -f1)
export GIT_SERVER=$(echo $IP | sed 's/\./-/g' | sed 's/:/-/g').sslip.io
GIT_USER={{ ztp_git_user }}
GIT_PASSWORD={{ ztp_git_password }}

mkdir -p /opt/gitea
chown -R 1000:1000 /opt/gitea
envsubst < /root/ztp/scripts/gitea.service > /etc/systemd/system/gitea.service
systemctl daemon-reload
systemctl enable gitea --now
sleep 20
podman exec --user 1000 gitea /bin/sh -c "gitea admin user create --username $GIT_USER --password $GIT_PASSWORD --email jhendrix@karmalabs.corp --must-change-password=false --admin"

# curl -u "$GIT_USER:$GIT_PASSWORD" -H 'Content-Type: application/json' -X POST --data '{"service":"2","clone_addr":"https://github.com/RHsyseng/5g-ran-deployments-on-ocp-lab.git","uid":1,"repo_name":"5g-ran-deployments-on-ocp-lab"}' http://$GIT_SERVER:3000/api/v1/repos/migrate
