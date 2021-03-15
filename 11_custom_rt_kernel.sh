export PATH=/root/bin:$PATH
KERNEL_SRC={{ custom_rt_kernel_src_url }}
KERNEL_VER={{ custom_rt_kernel_version }}
KERNEL_NODE_ROLE={{ custom_rt_kernel_node_role }}
cat <<EOF | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: rtos-entrypoint
data:
  entrypoint.sh: |
    #!/bin/sh

    set -euo pipefail
    echo "###################################"
    echo "Script to enable rt kernel"
    echo "###################################"

    TEMPDIR=\$(mktemp -d)

    # Fetch required packages
    for package in 'core' 'modules' 'modules-extra'; do
      curl -s ${KERNEL_SRC}/kernel-rt-\${package}-${KERNEL_VER}.rpm -o \${TEMPDIR}/kernel-rt-\${package}-${KERNEL_VER}.rpm
    done

    # Swap to RT kernel
    rpm-ostree override remove kernel{,-core,-modules,-modules-extra} \
      --install \${TEMPDIR}/kernel-rt-core-${KERNEL_VER}.rpm \
      --install \${TEMPDIR}/kernel-rt-modules-${KERNEL_VER}.rpm \
      --install \${TEMPDIR}/kernel-rt-modules-extra-${KERNEL_VER}.rpm
      
    rm -Rf \${TEMPDIR}

    # Reboot to apply changes
    systemctl reboot
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: rtos-ds
  labels:
    app: rtos-ds
spec:
  selector:
    matchLabels:
      app: rtos-ds
  template:
    metadata:
      labels:
        app: rtos-ds
    spec:
      hostNetwork: true
      nodeSelector:
        ${KERNEL_NODE_ROLE}: ""
      containers:
      - name: rtos-loader
        image: ubi8/ubi-minimal
        command: ['sh', '-c', 'cp /script/entrypoint.sh /host/tmp && chmod +x /host/tmp/entrypoint.sh && echo "applying rt kernel" && chroot /host /tmp/entrypoint.sh && sleep infinity']
        securityContext:
          privileged: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: FallbackToLogsOnError
        volumeMounts:
        - mountPath: /script
          name: rtos-script
        - mountPath: /host
          name: host
      hostNetwork: true
      restartPolicy: Always
      terminationGracePeriodSeconds: 10
      volumes:
      - configMap:
          name: rtos-entrypoint
        name: rtos-script
      - hostPath:
          path: /
          type: Directory
        name: host
EOF
