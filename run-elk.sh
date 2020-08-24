#!/bin/bash

CUR_DIR=$(dirname "$(readlink -f "$0")")
DATA_DIR=${CUR_DIR}/data
ES_DATA_DIR=${CUR_DIR}/data/elasticsearch/data
ES_PLUGINS_DIR=${CUR_DIR}/data/elasticsearch/plugins
NGINX_DIR=${CUR_DIR}/data/nginx
K8S_DIR=${CUR_DIR}/k8s-yaml

source ./tools.sh

# 几个镜像
function pull_images() {
    docker pull docker.elastic.co/elasticsearch/elasticsearch:7.8.1
    docker pull docker.elastic.co/kibana/kibana:7.8.1
    docker pull nginx
}

# 创建hostpath挂载目录
function create_elasticsearch_data_dir() {
    echo "Create host data dir {${CUR_DIR}/data/elasticsearch} for elasticsearch"
    mkdir -p ${ES_DATA_DIR}
    mkdir -p ${ES_PLUGINS_DIR}
}

function create_nginx_data_dir() {
    echo "Create nginx conf and share dir: ${NGINX_DIR}/share"
    # 访问路径/share，获取分享文件夹./data/nginx/share的文件列表
    mkdir -p ${NGINX_DIR}/share
    mkdir -p ${NGINX_DIR}/conf.d
    cp ${CUR_DIR}/share-nginx.conf ${NGINX_DIR}/conf.d/
    touch ${NGINX_DIR}/share/test-file.txt
}

function replace_env() {
    
    file_rpaths=("${CUR_DIR}/k8s-yaml/elasticsearch-statefulSet.yaml" "${CUR_DIR}/k8s-yaml/nginx-deployment.yaml")
    for file_rpath in ${file_rpaths[@]}; 
    do
        echo "Replace \${DATA_DIR} in ${file_rpath} to ${DATA_DIR}"
        sed -i "s#\${DATA_DIR}#${DATA_DIR}#" ${file_rpath}
    done
}

function deploy() {
    # namespace elk
    echo 'Create namespace "elk" on k8s'
    kubectl apply -f ${K8S_DIR}/elastic-stack-namespace.yaml

    echo "Create nginx-filebeat-configmap"
    kubectl apply -f ${K8S_DIR}/nginx-filebeat-settings-configmap.yaml

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

    # nginx
    echo "Create nginx deployment and service"
    kubectl create -f ${K8S_DIR}/nginx-deployment.yaml -f ${K8S_DIR}/nginx-service.yaml
}

pull_images
replace_env
create_data_dir
create_nginx_data_dir
download_analyzer ${ES_PLUGINS_DIR} 
deploy
