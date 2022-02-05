export CRYPTOGRAPHY_DONT_BUILD_RUST=1
pip3 install -U pip
pip3 install python-ironicclient --ignore-installed PyYAML
ssh core@api.{{ cluster }}.{{ domain }} "sudo chown core /opt/metal3/auth/clouds.yaml"
scp core@api.{{ cluster}}.{{ domain }}:/opt/metal3/auth/clouds.yaml /root
