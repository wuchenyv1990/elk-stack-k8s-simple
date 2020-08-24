#!/bin/bash

CUR_DIR=$(dirname "$(readlink -f "$0")")
K8S_DIR=${CUR_DIR}/k8s-yaml

# nginx
echo "Delete nginx deployment, service, configmap"
kubectl delete -f ${K8S_DIR}/nginx-deployment.yaml -f ${K8S_DIR}/nginx-service.yaml -f ${K8S_DIR}/nginx-filebeat-settings-configmap.yaml

# kibana
echo "Delete kibana deployment, service"
kubectl delete -f ${K8S_DIR}/kibana-service.yaml -f ${K8S_DIR}/kibana-deployment.yaml

# elasticsearch
echo "Delete elasticsearch deployment, service"
kubectl delete -f ${K8S_DIR}/elasticsearch-service.yaml -f ${K8S_DIR}/elasticsearch-statefulSet.yaml

# namespace elk
echo 'Delete namespace "elk" on k8s'
kubectl delete -f ${K8S_DIR}/elastic-stack-namespace.yaml
