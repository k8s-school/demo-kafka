#!/bin/bash

# Install and configure Harbor

# @author  Fabrice Jammes

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/conf.sh

argocd login --core
kubectl config set-context --current --namespace="$argocd_ns"

argocd app create "$app_name" --dest-server https://kubernetes.default.svc \
    --dest-namespace "$argocd_ns" \
    --repo "$cd_repo" \
    --path cd

argocd app sync "$app_name"

ink "Synk operator dependencies for $app_name"
argocd app sync -l app.kubernetes.io/part-of=$app_name,app.kubernetes.io/component=operator
argocd app wait -l app.kubernetes.io/part-of=$app_name,app.kubernetes.io/component=operator

ink "Synk all apps for $app_name"
argocd app sync -l app.kubernetes.io/part-of=harbor-registry

