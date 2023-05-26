#!/usr/bin/env bash

set -euo pipefail
export PYTHONUNBUFFERED=true

{% for app in apps %}
{% if (app.name is defined and app.name == 'users') or app == 'users' %}
kcli create app openshift {% if app.name is defined %}{{ app.name }}{% else %}{{ app }}{% endif %} -P users_admin={{ users_admin }} -P users_adminpassword={{ users_adminpassword }} -P users_dev={{ users_dev }} -P users_devpassword={{ users_devpassword }}
{% else %}
kcli create app openshift {% if app.name is defined %}{{ app.name }}{% else %}{{ app }}{% endif %}{% if app.parameters is defined %}{% for key, value in app.parameters.items() %} -P {{ key }}={{ value }}{% endfor %}{% else %} -P install_cr=false{% endif %}

{% endif %}
{% endfor %}
