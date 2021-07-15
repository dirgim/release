#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

# steps involved inside the configure proxy registry 
# 0. needs to add the pull secrets provided by 
# mirroring the pull secrets

# add brew pull secret 
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=/var/run/brew-pullsecret/.dockerconfigjson

# 1. Apply the ICSP to the cluster 
echo "Creating new proxy registry record on cluster"
OO_CONFIGURE_PROXY_REGISTRY=$(
    oc create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: brew-registry
spec:
  repositoryDigestMirrors:
  - mirrors:
    - brew.registry.redhat.io
    source: registry.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry.stage.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry-proxy.engineering.redhat.com
  - mirrors:
    - brew.registry.redhat.io
    source: registry-proxy-stage.engineering.redhat.com
EOF
)
echo "Configuring proxy registry : \"$OO_CONFIGURE_PROXY_REGISTRY\""

# Sleep for 2 minutes to allow for the nodes to begin restarting
sleep 120
# Query the node state until all of the nodes are ready
for i in {1..60}; do
    NODE_STATE="$(oc get nodes || echo "ERROR")"
    if [[ ${NODE_STATE} == *"NotReady"*  || ${NODE_STATE} == *"SchedulingDisabled"* ]]; then
        echo "Not all of the nodes have finished restarting - waiting for 30 seconds, attempt ${i}"
        sleep 30
    elif [[ ${NODE_STATE} == "ERROR" ]]; then
        echo "Encountered an issue querying the OpenShift API - waiting for 30 seconds, attempt ${i}"
        sleep 30
    else
        echo "All nodes ready"
        break
    fi
done
