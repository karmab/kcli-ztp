export HTTP_PROXY=http://{{ 'http://' + http_proxy if 'http' not in http_proxy else http_proxy }}
export HTTPS_PROXY=$HTTP_PROXY
export http_proxy=$HTTP_PROXY
export https_proxy=$HTTP_PROXY
{% if no_proxy != None %}
export NO_PROXY={{ no_proxy }}
{% else %}
export NO_PROXY={{ baremetal_cidr }}
{% endif %}
export no_proxy=$NO_PROXY
