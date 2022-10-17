#!/usr/bin/env bash

set -euo pipefail
export PYTHONUNBUFFERED=true

{% for app in apps %}
kcli create app openshift $app -P install_cr=false
{% endfor %}
