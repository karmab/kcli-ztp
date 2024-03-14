#!/usr/bin/env bash

CLUSTER={{ cluster }}
[ -d /root/ocp ] && rm -rf /root/ocp
VMS=$(kcli list vm | grep ${CLUSTER}-.*-bootstrap | cut -d"|" -f 2 | xargs)
[ -z "$VMS" ] || kcli delete vm --yes $VMS
