OCP_RELEASE=$(/root/bin/openshift-baremetal-install version | head -1 | cut -d' ' -f2)-x86_64
export MINOR=$(echo $OCP_RELEASE | cut -d. -f1,2)
export PULLSECRET=$(cat /root/openshift_pull.json | tr -d [:space:])
export DOMAIN={{ domain }}
export SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)
envsubst < /root/ztp/scripts/siteconfig_requirements.sample.yml > /root/spokes.yml
envsubst < /root/ztp/scripts/siteconfig.sample.yml >> /root/siteconfig.yml

bash /root/ztp/scripts/bmc_siteconfig.sh

podman pull quay.io/openshift-kni/ztp-site-generator:latest
podman create -ti --name ztp-site-gen ztp-site-generator:latest bash
podman cp ztp-site-gen:/home/ztp /root/out
podman run --security-opt label=disable -v /root:/workdir quay.io/karmab/siteconfig-generator -manifestPath /workdir/out/extra-manifest /workdir/siteconfig.yml >> /root/spokes.yml
