apt-get update
apt-get -y install libvirt-daemon libvirt0 qemu-system-x86 qemu-utils qemu-kvm libvirt-daemon-system curl genisoimage python3-libvirt qemu-user-static podman
setfacl -m u:runner:rwx /var/run/libvirt/libvirt-sock
curl -s https://raw.githubusercontent.com/karmab/kcli/master/install.sh | bash
