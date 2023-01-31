#!/usr/bin/env bash

for config_file in "$(dirname "$(realpath "$0")")"/conf/clusters/*.yaml
do
  cluster_name=tap-$(basename "$config_file" | sed 's/\..*$//')-cluster
  >&2 echo "===> Installing cluster $cluster_name"
  kind create cluster --name "$cluster_name" --config "$config_file" || exit 1
done
