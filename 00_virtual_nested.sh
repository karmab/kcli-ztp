yum -y install libvirt libvirt-daemon-driver-qemu qemu-kvm
systemctl enable --now libvirtd
ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa
