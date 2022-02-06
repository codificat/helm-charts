#!/bin/bash

# TEST-ENV: bring up a cluster
sudo podman run -d --rm --name microshift --privileged \
     -v microshift-data:/var/lib -p 6443:6443 -p 80:80 -p 443:443 \
     quay.io/microshift/microshift-aio:latest
sudo podman exec microshift bash -c \
     'while ! test -f "/var/lib/microshift/resources/kubeadmin/kubeconfig"; do
         echo "Waiting for kubeconfig..."
         sleep 5
     done'

export KUBECONFIG=/tmp/microshift-kubeconfig
sudo podman cp microshift:/var/lib/microshift/resources/kubeadmin/kubeconfig ${KUBECONFIG}
sudo chown ${USER} ${KUBECONFIG}
chmod 600 ${KUBECONFIG}

# wait for the cluster to be ready
kubectl wait --for=condition=available apiservice --all --timeout 300s

# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install --create-namespace --namespace metrics prometheus-stack prometheus-community/kube-prometheus-stack

# Install Tekton using tekton-operator
kubectl create ns openshift-operators
kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/latest/openshift-release.yaml
# to install pipelines and triggers only (use profile 'basic')
kubectl apply -f https://raw.githubusercontent.com/tektoncd/operator/main/config/crs/openshift/config/basic/operator_v1alpha1_config_cr.yaml

# workaround the lack of automatic CA cert info from cluster network operator
while : ; do
  kubectl get namespace openshift-pipelines && sleep 5 && break
  sleep 5
done
# NOTE: the path is for red hat based OSs
kubectl create configmap config-trusted-cabundle \
        --from-file=ca-bundle.crt=/etc/pki/tls/certs/ca-bundle.crt \
        --dry-run=client -o yaml | \
    kubectl apply -n openshift-pipelines -f -

# wait for Tekton components to become available
kubectl wait tektonconfig config --for condition=ComponentsReady --timeout 600s

# TEST: install+test the pipelines
podman run --rm -v ${PWD}:${PWD}:z -w ${PWD} \
       --net slirp4netns:allow_host_loopback=true \
       -v ${KUBECONFIG}:/kubeconfig:Z -e KUBECONFIG=/kubeconfig \
       quay.io/helmpack/chart-testing:latest ct install --config .chart-testing.yaml

# TEST-CASE: at least this secret should be there
# kubectl get secret quay-pusher-secret --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode | jq .auths

# TEST-ENV: tear down the cluster
# TODO based on microshift's hack/cleanup.sh
