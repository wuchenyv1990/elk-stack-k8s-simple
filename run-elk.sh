#!/bin/bash

CUR_DIR=$(dirname "$(readlink -f "$0")")
DATA_DIR=${CUR_DIR}/data
ES_DATA_DIR=${CUR_DIR}/data/elasticsearch/data
ES_PLUGINS_DIR=${CUR_DIR}/data/elasticsearch/plugins
K8S_DIR=${CUR_DIR}/k8s-yaml

source ./tools.sh

# 几个镜像
function pull_images() {
    docker pull docker.elastic.co/elasticsearch/elasticsearch:7.8.1
    docker pull docker.elastic.co/kibana/kibana:7.8.1
    docker pull nginx
}

# 创建hostpath挂载目录
function create_elasticsearch_dir() {
    echo "Create host data dir {${CUR_DIR}/data/elasticsearch} for elasticsearch"
    mkdir -p ${ES_DATA_DIR}
    mkdir -p ${ES_PLUGINS_DIR}
}

function replace_env() {
    echo "Replace \${DATA_DIR} in elasticsearch-statefulSet.yaml to ${DATA_DIR}"
    sed -i "s#\${DATA_DIR}#${DATA_DIR}#" ${CUR_DIR}/k8s-yaml/elasticsearch-statefulSet.yaml
}

function deploy() {
    
    # namespace elk
    echo 'Create namespace "elk" on k8s'
    kubectl apply -f ${K8S_DIR}/elastic-stack-namespace.yaml

    # elasticsearch
    echo "Create elasticsearch-statefulSet"
    kubectl create -f ${K8S_DIR}/elasticsearch-statefulSet.yaml
    echo "Create elasticsearch-service"
    kubectl create -f ${K8S_DIR}/elasticsearch-service.yaml

    # kibana
    echo "Create kibana-deployment"
    kubectl create -f ${K8S_DIR}/kibana-deployment.yaml
    echo "Create kibana-service"
    kubectl create -f ${K8S_DIR}/kibana-service.yaml
}

pull_images
create_elasticsearch_dir
download_analyzer ${ES_PLUGINS_DIR} 
replace_env
deploy
