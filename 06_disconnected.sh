export PATH=/root/bin:$PATH
export PULL_SECRET="/root/openshift_pull.json"
dnf -y install podman httpd httpd-tools jq bind-utils
IP=$(hostname -I | cut -d' ' -f1)
REVERSE_NAME=$(dig -x $IP +short | sed 's/\.[^\.]*$//')
REGISTRY_NAME=${REVERSE_NAME:-$(hostname -f)}
KEY=$( echo -n {{ registry_user }}:{{ registry_password }} | base64)
jq ".auths += {\"$REGISTRY_NAME:5000\": {\"auth\": \"$KEY\",\"email\": \"jhendrix@karmalabs.com\"}}" < $PULL_SECRET > /root/temp.json
mkdir -p /opt/registry/{auth,certs,data}
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt -subj "/C=US/ST=Madrid/L=San Bernardo/O=Karmalabs/OU=Guitar/CN=$REGISTRY_NAME" -addext "subjectAltName=DNS:$REGISTRY_NAME"
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
htpasswd -bBc /opt/registry/auth/htpasswd {{ registry_user }} {{ registry_password }}
podman create --name registry --net host --security-opt label=disable -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key {{ registry_image }}
podman start registry
export OPENSHIFT_RELEASE_IMAGE={{ openshift_image }}
export OCP_RELEASE=$( echo $OPENSHIFT_RELEASE_IMAGE | cut -d: -f2)
export LOCAL_REG="$REGISTRY_NAME:5000"
export LOCAL_REPO='ocp/release'
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=${LOCAL_REG}/${LOCAL_REPO}:${OCP_RELEASE}
mv /root/temp.json $PULL_SECRET
oc adm release mirror -a $PULL_SECRET --from=$OPENSHIFT_RELEASE_IMAGE --to-release-image=$LOCAL_REG/$LOCAL_REPO:$OCP_RELEASE --to=$LOCAL_REG/$LOCAL_REPO
echo "{\"auths\": {\"$REGISTRY_NAME:5000\": {\"auth\": \"$KEY\", \"email\": \"jhendrix@karmalabs.com\"}}}" > /root/temp.json

grep -q imageContentSources /root/install-config.yaml
if [ "$?" != "0" ] ; then
cat << EOF >> /root/install-config.yaml
imageContentSources:
- mirrors:
  - $REGISTRY_NAME:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
- mirrors:
  - $REGISTRY_NAME:5000/ocp4/openshift4
  source: registry.ci.openshift.org/ocp/release
EOF
else
  IMAGECONTENTSOURCES="- mirrors:\n  - $REGISTRY_NAME:5000/ocp4/openshift4\n  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev\n- mirrors:\n  - $REGISTRY_NAME:5000/ocp4/openshift4\n  source: registry.ci.openshift.org/ocp/release"
  sed -i "/imageContentSources/a${IMAGECONTENTSOURCES}" /root/install-config.yaml
fi
grep -q additionalTrustBundle /root/install-config.yaml
if [ "$?" != "0" ] ; then
  echo "additionalTrustBundle: |" >> /root/install-config.yaml
  sed -e 's/^/  /' /opt/registry/certs/domain.crt >>  /root/install-config.yaml
else
  LOCALCERT="-----BEGIN CERTIFICATE-----\n $(grep -v CERTIFICATE /opt/registry/certs/domain.crt | tr -d '[:space:]')\n  -----END CERTIFICATE-----"
  sed -i "/additionalTrustBundle/a${LOCALCERT}" /root/install-config.yaml
  sed -i 's/^-----BEGIN/  -----BEGIN/' /root/install-config.yaml
fi
