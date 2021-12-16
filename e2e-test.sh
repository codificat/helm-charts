#!/bin/bash

set -ex

# PREREQUISITE: `helm` and `kubectl` are installed

# PREREQUISITE: a kubernetes / openshift cluster is available and configured

# TEST-ENV: bring up a cluster
# GO111MODULE="on" go install sigs.k8s.io/kind@v0.11.1
# kind create cluster

# PREREQUISITE: deploy tekton
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.28.2/release.notags.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/v0.16.1/release.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/v0.16.1/interceptors.yaml
#oc adm policy add-scc-to-user anyuid -z tekton-pipelines-controller

# PREREQUISITE: deploy prometheus (needed for ServiceMonitor)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install --create-namespace --namespace metrics \
     prometheus-stack prometheus-community/kube-prometheus-stack

# TEST: deploy meteor-pipelines
#oc adm policy add-scc-to-user privileged -z aicoe-ci -n tekton-pipelines
helm install --create-namespace --namespace=thoth-aidevsecops-pipelines \
     thoth-pipelines charts/meteor-pipelines

# TEST-CASE: at least this secret should be there
# kubectl get secret quay-pusher-secret --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode | jq .auths

# TEST-ENV: tear down the cluster
# kind delete cluster
