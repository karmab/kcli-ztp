#!/usr/bin/env bash

set -euo pipefail
export PYTHONUNBUFFERED=true

{% for app in apps %}
{% set app_name = app.name if app.name is defined else app %}
{% if app_name == 'users' %}
kcli create app {{ app_name }} -P users_admin={{ users_admin }} -P users_adminpassword={{ users_adminpassword }} -P users_dev={{ users_dev }} -P users_devpassword={{ users_devpassword }}
{% else %}
{% set install_cr = '-P install_cr=false' if not apps_install_cr else '' %}
kcli create app {{ app_name }}{% if app.parameters is defined %}{% for key, value in app.parameters.items() %} -P {{ key }}={{ value }}{% endfor %}{% else %} {{ install_cr }}{% endif %}

{% endif %}
{% endfor %}
