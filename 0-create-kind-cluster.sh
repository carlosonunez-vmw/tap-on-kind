#!/usr/bin/env bash
REGISTRY_FILES_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/registry"
CONFIG_FILE_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/cluster_configs"
CERT_PATH="$REGISTRY_FILES_PATH/certs"
CONFIG_FILE_TEMPLATE_PATH="$(dirname "$(realpath "$0")")/conf/cluster_template.yaml"

http_port=8080
https_port=8443
test -d "$CONFIG_FILE_PATH" || mkdir -p "$CONFIG_FILE_PATH"
for cluster_name in build run iterate view
do
  modified_config_path="$CONFIG_FILE_PATH/$cluster_name.yaml"
  sed "s#%CERT_PATH%#$CERT_PATH#g; s#%HTTP_PORT%#$http_port#g; s#%HTTPS_PORT%#$https_port#g;" \
    "$CONFIG_FILE_TEMPLATE_PATH" > "$modified_config_path"
  cluster_name="tap-$cluster_name-cluster"
  http_port=$((http_port+1))
  https_port=$((https_port+1))
  >&2 echo "===> Installing cluster $cluster_name"
  kind create cluster --name "$cluster_name" --config "$modified_config_path" || exit 1
done
