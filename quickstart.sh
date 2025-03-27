#!/bin/bash

set -euxo pipefail

# From https://strimzi.io/quickstarts/

kubectl delete namespace -l kafka=true

kubectl create namespace kafka
kubectl label namespace kafka kafka=true

ink "Install Strimzi"
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

ink "Deploy a Kafka cluster"
kubectl apply -f https://strimzi.io/examples/latest/kafka/kraft/kafka-single-node.yaml -n kafka

kubectl wait pod --for=condition=Ready --all -n kafka --timeout=300s
kubectl exec -it my-cluster-dual-role-0 -c kafka -n kafka -- bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --list