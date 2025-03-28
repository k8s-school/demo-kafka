#!/bin/bash

# Install a kafka cluster from scratch

# @author  Fabrice Jammes

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

$DIR/prereq.sh
$DIR/argocd.sh
$DIR/e2e.sh
