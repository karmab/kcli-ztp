BASEDIR=$(dirname $0)
SPOKE=$(basename $BASEDIR | cut -d_ -f2)
for entry in $BASEDIR/manifests/* ; do
manifest_clean=$(basename $entry)
manifest=$(echo $manifest_clean | sed "s/\./-/g" | sed "s/_/-/g")
echo """kind: ConfigMap
apiVersion: v1
metadata:
  name: $manifest
  namespace: $SPOKE
data:""" >> $BASEDIR/manifests.yml
echo " $manifest_clean : |" >> $BASEDIR/manifests.yml
sed -e "s/^/  /g" $entry >> $BASEDIR/manifests.yml
echo -e "---" >> $BASEDIR/manifests.yml
done
