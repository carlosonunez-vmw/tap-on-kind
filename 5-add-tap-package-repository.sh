#!/usr/bin/env bash
kubernetes_clusters_started() {

  clusters=$(kind get clusters)
  for cluster in "$(dirname "$0")"/conf/clusters/*.yaml
  do
    name=tap-$(awk -F '/' '{print $NF}' <<< "$cluster" | cut -f1 -d '.')-cluster
    grep -q "$name" <<< "$clusters" || return 1
  done
}

kubernetes_clusters() {
  find "$(dirname "$0")"/conf/clusters/*.yaml -exec basename {} \; | sed 's/.yaml$//'
}

kubectl_cmd() {
  cmd=(kubectl --context="kind-tap-$1-cluster" "${@:2}")
  >&2 echo "========> ${cmd[*]}"
  "${cmd[@]}"
}

create_namespace_on_all_clusters() {
  for cluster in $(kubernetes_clusters)
  do
    kubectl_cmd "$cluster" get ns tap-install >/dev/null ||
      kubectl_cmd "$cluster" create ns tap-install
  done
}


if ! kubernetes_clusters_started
then
  >&2 echo "ERROR: None or some Kubernetes clusters missing. \
Please run 0-create-kind-cluster before running this script."
  exit 1
fi

create_namespace_on_all_clusters
