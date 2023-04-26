#!/usr/bin/env bash

set -euo pipefail
export PYTHONUNBUFFERED=true

{% for app in apps %}
{% if app == 'users' %}
kcli create app openshift {{ app }} -P users_admin={{ users_admin }} -P users_adminpassword={{ users_adminpassword }} -P users_dev={{ users_dev }} -P users_devpassword={{ users_devpassword }}
{% else %}
kcli create app openshift {{ app }} -P install_cr=false
{% endif %}
{% endfor %}
