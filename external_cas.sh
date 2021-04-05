#!/usr/bin/env bash

{%- if cas is defined %}
counter=1
{% for ca in cas %}
file=/etc/pki/ca-trust/source/anchors/RH-IT-Root-CA$counter.crt
echo "-----BEGIN CERTIFICATE-----" >> $file
echo {{ ca }} >> $file
echo "-----END CERTIFICATE-----" >> $file
counter=$((counter+1))
{% endfor %}
update-ca-trust
{%- endif %}
