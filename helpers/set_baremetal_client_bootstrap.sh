export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install -U pip
pip3 install python-ironicclient --ignore-installed PyYAML
ssh core@{{ api_ip }} "sudo chown core /opt/metal3/auth/clouds.yaml"
scp core@{{ api_ip}}:/opt/metal3/auth/clouds.yaml /root
