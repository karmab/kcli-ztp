#!/usr/bin/env bash

#export SNAPSHOT=2.3.0-DOWNSTREAM-2021-06-07-19-53-02  -> https://quay.io/repository/acm-d/acm-custom-registry?tab=tags
#export ACM_OP_BUNDLE=v2.3.0-117 -> https://quay.io/repository/acm-d/acm-operator-bundle?tab=tags

yum -y install skopeo
export IP=$(ip -o addr show eth0 | head -1 | awk '{print $4}' | cut -d'/' -f1)
REVERSE_NAME=$(dig -x $IP +short | sed 's/\.[^\.]*$//')
echo $IP | grep -q ':' && SERVER6=$(grep : /etc/resolv.conf | grep -v fe80 | cut -d" " -f2) && REVERSE_NAME=$(dig -6x $IP +short @$SERVER6 | sed 's/\.[^\.]*$//')
REGISTRY_NAME=${REVERSE_NAME:-$(hostname -f)}
export SNAPSHOT={{ acm_snapshot }}
export ACM_OP_BUNDLE={{ acm_op_bundle }}
#export SNAPSHOT=$(podman image search --list-tags quay.io/acm-d/acm-custom-registry --limit 20000 | tail -1 | cut -d" " -f3)
#export ACM_OP_BUNDLE=$(podman image search --list-tags quay.io/acm-d/acm-operator-bundle --limit 20000 | tail -1 | cut -d" " -f3)
export PULL_SECRET_JSON=/root/openshift_pull_acm.json
export LOCAL_REGISTRY=$REGISTRY_NAME:5000
export IMAGE_INDEX=quay.io/acm-d/acm-custom-registry
export BUILD_FOLDER=./build

KEY=$( echo -n {{ disconnected_user }}:{{ disconnected_password }} | base64)
jq ".auths += {\"$REGISTRY_NAME:5000\": {\"auth\": \"$KEY\",\"email\": \"jhendrix@karmalabs.com\"}}" < $PULL_SECRET_JSON > /root/temp_acm.json
export PULL_SECRET_JSON=/root/temp_acm.json

# Clean previous tries
rm -rf ${BUILD_FOLDER}

# Copy ACM Custom Registry index and bundle images
echo
echo ">>>>>>>>>>>>>>> Cloning the Index and Bundle images..."
skopeo copy --authfile ${PULL_SECRET_JSON} --all docker://quay.io:443/acm-d/acm-custom-registry:${SNAPSHOT} docker://${LOCAL_REGISTRY}/rhacm2/acm-custom-registry:${SNAPSHOT}
skopeo copy --authfile ${PULL_SECRET_JSON} --all docker://quay.io:443/acm-d/acm-operator-bundle:${ACM_OP_BUNDLE} docker://${LOCAL_REGISTRY}/rhacm2/acm-operator-bundle:${ACM_OP_BUNDLE}

# Generate Mapping.txt
echo
echo ">>>>>>>>>>>>>>> Creating mapping assets..."
oc adm -a ${PULL_SECRET_JSON} catalog mirror ${IMAGE_INDEX}:${SNAPSHOT} ${LOCAL_REGISTRY} --manifests-only --to-manifests=${BUILD_FOLDER}

# Replace the upstream registry by the downstream one
sed -i s#registry.redhat.io/rhacm2/#quay.io/acm-d/# ${BUILD_FOLDER}/mapping.txt

# Mirror the images into your mirror registry.
echo
echo ">>>>>>>>>>>>>>> Mirroring images..."
oc image mirror -f ${BUILD_FOLDER}/mapping.txt -a ${PULL_SECRET_JSON} --filter-by-os=.* --keep-manifest-list --continue-on-error=true

echo
echo "export CUSTOM_REGISTRY_REPO=${LOCAL_REGISTRY}/rhacm2"
echo "export DEFAULT_SNAPSHOT=${SNAPSHOT}"
echo ">>>>Finished<<<<" >${BUILD_FOLDER}/finish

cp ${BUILD_FOLDER}/catalogSource.yaml /root/manifests/acm_catalogsource.yaml
cp ${BUILD_FOLDER}/imageContentSourcePolicy.yaml /root/manifests/acm_icsp.yaml

echo """apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: acm-custom-registry-extra
spec:
  repositoryDigestMirrors:
  - mirrors:
    - ${LOCAL_REGISTRY}/acm-d
    source: quay.io/acm-d""" > /root/manifests/acm_icsp_2.yaml

oc create -f /root/manifests/acm_catalogsource.yaml
oc create -f /root/manifests/acm_icsp.yaml
oc create -f /root/manifests/acm_icsp_2.yaml
ln -s /root/manifests /root/manifests-redhat-operator-index-0
cp /root/manifests/acm_icsp.yaml /root/manifests/imageContentSourcePolicy.yaml

sleep 360
for i in `oc get node -o wide | awk '{print $6}' | grep -v INTERN` ; do ssh core@$i "sudo sed -i 's/mirror-by-digest-only = true/mirror-by-digest-only = false/' /etc/containers/registries.conf && sudo systemctl restart kubelet crio" ; done
sleep 120
