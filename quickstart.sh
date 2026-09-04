#!/bin/bash

set -euxo pipefail

# From https://strimzi.io/quickstarts/

kubectl delete namespace -l kafka=true

kubectl create namespace kafka
kubectl label namespace kafka kafka=true

ink "Install Strimzi"
# server-side apply, not create: deleting the namespace above leaves Strimzi's
# CLUSTER-scoped objects behind (CRDs, ClusterRoles), so a second run of this
# script used to die on "AlreadyExists". --server-side also avoids the
# "metadata.annotations: Too long" limit that a plain apply hits on these CRDs.
kubectl apply --server-side --force-conflicts -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

ink "Wait for the Strimzi operator to be ready"
kubectl wait deployment/strimzi-cluster-operator --for=condition=Available -n kafka --timeout=300s

ink "Deploy a Kafka cluster"
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml -n kafka

# Wait on the Kafka CUSTOM RESOURCE, not on the pods: right after 'apply' the
# operator has not created the broker pods yet, so 'kubectl wait pod --all'
# matches only the operator itself and returns immediately -- the next command
# then talks to a broker that is not listening.
ink "Wait for the operator to reconcile the Kafka cluster"
kubectl wait kafka/my-cluster --for=condition=Ready -n kafka --timeout=300s

ink "List the topics"
kubectl exec my-cluster-dual-role-0 -c kafka -n kafka -- bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --list
