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

# The revision ArgoCD must read cd/ and kafka/ from. This repository is its own
# CD repository, so without it ArgoCD falls back to the default branch and a
# change to cd/ or kafka/ pushed on a feature branch is never the thing CI
# tests -- it silently re-tests main, and the branch goes green on code nobody
# ran. That is exactly how the Strimzi 1.2.0 migration reached main untested.
#
# Not ciux's *_WORKBRANCH: that resolves the branch to use in DEPENDENCY
# repositories and stays "main" for the project itself, even with --branch.
if [ -n "${GITHUB_HEAD_REF:-}" ]; then
    revision="$GITHUB_HEAD_REF"        # pull request: the source branch
elif [ -n "${GITHUB_REF_NAME:-}" ]; then
    revision="$GITHUB_REF_NAME"        # push: the branch being built
else
    revision=$(git -C "$DIR" rev-parse --abbrev-ref HEAD)
fi
ink "Deploying cd/ and kafka/ from revision '$revision'"

# --revision points the root Application at that branch; -p overrides the Helm
# value the child Applications (cd/templates/*.yaml) use for their own source.
# Both are needed: they are two different levels of the app-of-apps.
argocd app create "$app_name" --dest-server https://kubernetes.default.svc \
    --dest-namespace "$argocd_ns" \
    --repo "$cd_repo" \
    --path cd \
    --revision "$revision" \
    -p spec.source.targetRevision.default="$revision" \
    --upsert

argocd app sync --timeout "$argocd_timeout" "$app_name"

ink "Synk operator dependencies for $app_name"
argocd app sync --timeout "$argocd_timeout" \
    -l app.kubernetes.io/part-of=$app_name,app.kubernetes.io/component=operator
argocd app wait --timeout "$argocd_timeout" \
    -l app.kubernetes.io/part-of=$app_name,app.kubernetes.io/component=operator || diagnose

ink "Synk all apps for $app_name"
argocd app sync --timeout "$argocd_timeout" -l app.kubernetes.io/part-of="$app_name"
argocd app wait --timeout "$argocd_timeout" \
    -l app.kubernetes.io/part-of="$app_name" || diagnose

