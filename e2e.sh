#!/bin/bash

# Prepare the environment for e2e tests

# @author  Fabrice Jammes

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/conf.sh

# FIXME: work randomly
kubectl exec -it kafka-cluster-dual-role-0 -c kafka -n kafka -- bin/kafka-topics.sh --bootstrap-server kafka-cluster-kafka-bootstrap.kafka:9092 --list
