{% if schedulable_ctlplanes %}
echo "Setting ctlplane nodes schedulable"
oc patch scheduler cluster -p '{"spec":{"mastersSchedulable": true}}' --type merge
{% endif %}
