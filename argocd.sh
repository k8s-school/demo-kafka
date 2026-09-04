#!/bin/bash

# Register this repository as an ArgoCD application and sync it

# @author  Fabrice Jammes

set -euxo pipefail

DIR=$(cd "$(dirname "$0")"; pwd -P)

. $DIR/conf.sh

# 'argocd app wait' blocks forever by default: an application that never turns
# Healthy pins the CI job until GitHub's 6-hour job timeout kills it, with no
# usable log. Bounded waits turn that into a normal failure with a diagnosis.
argocd_timeout=600

# Print what ArgoCD thinks is wrong, then fail. Called when a wait times out,
# because 'argocd app wait' says nothing useful on its way out.
diagnose() {
    set +x
    ink -r "ArgoCD did not converge in ${argocd_timeout}s -- current state:"
    argocd app list -o wide || true
    for app in $(argocd app list -o name || true); do
        ink -y "--- $app"
        argocd app get "$app" || true
    done
    kubectl get pods -A || true
    exit 1
}

argocd login --core
kubectl config set-context --current --namespace="$argocd_ns"

argocd app create "$app_name" --dest-server https://kubernetes.default.svc \
    --dest-namespace "$argocd_ns" \
    --repo "$cd_repo" \
    --path cd

argocd app sync "$app_name"

ink "Synk operator dependencies for $app_name"
argocd app sync -l app.kubernetes.io/part-of=$app_name,app.kubernetes.io/component=operator
argocd app wait --timeout "$argocd_timeout" \
    -l app.kubernetes.io/part-of=$app_name,app.kubernetes.io/component=operator || diagnose

ink "Synk all apps for $app_name"
argocd app sync -l app.kubernetes.io/part-of="$app_name"
argocd app wait --timeout "$argocd_timeout" \
    -l app.kubernetes.io/part-of="$app_name" || diagnose

