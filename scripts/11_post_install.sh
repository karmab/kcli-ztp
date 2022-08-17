{% if schedulable_masters %}
echo "Setting master nodes schedulable"
oc patch scheduler cluster -p '{"spec":{"mastersSchedulable": true}}' --type merge
{% endif %}
