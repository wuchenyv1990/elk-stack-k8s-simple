#!/bin/bash

CUR_DIR=$(dirname "$(readlink -f "$0")")
K8S_DIR=${CUR_DIR}/k8s-yaml

# kibana
echo "Delete kibana-service"
kubectl delete -f ${K8S_DIR}/kibana-service.yaml
echo "Delete kibana-deployment"
kubectl delete -f ${K8S_DIR}/kibana-deployment.yaml

# elasticsearch
echo "Delete elasticsearch-service"
kubectl delete -f ${K8S_DIR}/elasticsearch-service.yaml
echo "Dreate elasticsearch-deployment"
kubectl delete -f ${K8S_DIR}/elasticsearch-statefulSet.yaml

# namespace elk
echo 'Delete namespace "elk" on k8s'
kubectl delete -f ${K8S_DIR}/elastic-stack-namespace.yaml
