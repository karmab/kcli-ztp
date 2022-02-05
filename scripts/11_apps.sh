{% for app in apps %}
tasty install {{ app }} -w
{% endfor %}
