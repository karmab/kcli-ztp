#!/bin/bash

oc get csr -o name | xargs oc adm certificate approve
