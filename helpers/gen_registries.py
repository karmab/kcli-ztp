#!/usr/bin/env python3

import yaml

results = ''
with open('/root/manifests/imageContentSourcePolicy.yaml') as f:
    data = yaml.safe_load(f)

mirrors = data['spec']['repositoryDigestMirrors']
for mirror in mirrors:
    registry1 = mirror['source']
    registry2 = mirror['mirrors'][0]
    results += """\n    [[registry]]
    prefix = ""
    location = "{registry1}"
    mirror-by-digest-only = true

    [[registry.mirror]]
      location = "{registry2}"\n""".format(registry1=registry1, registry2=registry2)

print(results)
