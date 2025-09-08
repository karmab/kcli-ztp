timeout=0
compliant=false
while [ "$timeout" -lt "1800" ] ; do
  TOTAL_POLICIES=$(oc get policies -A -o name | wc -l)
  COMPLIANT_POLICIES=$(oc get policies -A -o jsonpath='{.items[*].status.compliant}' | wc -w)
  [ $TOTAL_POLICIES != "0" ] && [ "$TOTAL_POLICIES" == "$COMPLIANT_POLICIES" ] && compliant=true && break;
  echo "Waiting for all policies to be marked as compliant"
  sleep 60
  timeout=$(($timeout + 60))
done

if [ "$compliant" == "true" ] ; then
  echo "All policies marked as compliant"
else
  echo Timeout waiting for policies to be compliant
fi
