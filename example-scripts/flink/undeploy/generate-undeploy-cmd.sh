#!/bin/bash

STREAMLET_FOLDER=$1
if [ -z "$STREAMLET_FOLDER" ]; then
    echo "No streamlet folder specified."
    exit 1
fi

APPLICATION=$2
if [ -z "$APPLICATION" ]; then
    echo "No application name specified."
    exit 1
fi

cluster_id=$(jq -rc '.name' ${STREAMLET_FOLDER}streamlet.json | sed s'/\./\-/')

mkdir -p "${STREAMLET_FOLDER}output"
OUTPUT_CMD="${STREAMLET_FOLDER}output/delete-cmd.sh"

# NOTE
# we need to cleanup the ConfigMaps manually as reported:
# https://issues.apache.org/jira/browse/FLINK-22262
#
cat > "${OUTPUT_CMD}" << EOF
    jobId=\$(kubectl get configmaps --namespace ${APPLICATION} -l app=${cluster_id} -o json | jq -r '.items[] | select(.metadata.name |  endswith("jobmanager-leader")) | .metadata.name' | sed s"/${cluster_id}-//" | sed s"/-jobmanager-leader//")
    flink cancel --target kubernetes-application -Dkubernetes.cluster-id=taxi-ride-fare-processor -Dkubernetes.namespace=taxi-ride-fare \$jobId
    kubectl delete deployment ${cluster_id} --namespace ${APPLICATION}
    kubectl delete configmaps -l app=${cluster_id} --namespace ${APPLICATION}
    kubectl wait --for=delete pods -l app=${cluster_id} --namespace ${APPLICATION}
    kubectl wait --for=delete services -l app=${cluster_id} --namespace ${APPLICATION}
EOF
chmod a+x "${OUTPUT_CMD}"
