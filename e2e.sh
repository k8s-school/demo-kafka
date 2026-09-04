#!/bin/bash

# Run the e2e tests

# @author  Fabrice Jammes

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/conf.sh

# Gate on the Kafka custom resource: 'argocd app wait' returns as soon as the
# manifests are synced, which happens well before the operator has finished
# creating and starting the brokers. Without this the kafka-topics.sh call below
# used to fail intermittently against a broker that was not listening yet.
kubectl wait kafka/kafka-cluster --for=condition=Ready -n kafka --timeout=600s

# No -it: there is no TTY in CI.
kubectl exec kafka-cluster-dual-role-0 -c kafka -n kafka -- bin/kafka-topics.sh --bootstrap-server kafka-cluster-kafka-bootstrap.kafka:9092 --list
