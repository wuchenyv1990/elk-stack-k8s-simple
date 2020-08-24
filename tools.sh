#!/bin/bash

# 参数1:podName, 参数2:namespace
function find_pod_by_name_ns() {
    pod_name=$1
    namespace=$2
    if [ -n "${namespace}" ]; then
        ns_filter="-n ${namespace}"
    fi
    echo `kubectl get pods ${ns_filter} | sed -n '2,\$p' | grep ${pod_name} | awk '{print $1;}'`
}

# 几个镜像
function pull_images() {
    docker pull docker.elastic.co/elasticsearch/elasticsearch:7.9.0
    docker pull docker.elastic.co/kibana/kibana:7.9.0
    docker pull docker.elastic.co/beats/filebeat:7.9.0
    docker pull nginx
}

# 下载中文分词器 elasticsearch-analysis-ik 
function download_analyzer() {
    if [ -n "$1" ]; then
        echo "needs param: ES_PLUGINS_DIR"
    fi
    ik_dir=$1/ik
    mkdir -p ${ik_dir}
    download_url="https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.9.0/elasticsearch-analysis-ik-7.9.0.zip"
    echo "start download elasticsearch-analysis-ik in to ${ik_dir}"
    wget -P ${ik_dir} -c ${download_url}
    echo "download success then unzip"
    file_name=`ls ${ik_dir} | grep elasticsearch`
    file_path=${ik_dir}/${file_name}
    unzip ${file_path} -d ${ik_dir} && rm -f ${file_path}
}
