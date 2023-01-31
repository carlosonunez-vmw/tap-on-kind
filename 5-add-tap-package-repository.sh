#!/usr/bin/env bash
CERT_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/registry/certs"

kubernetes_clusters_started() {
  clusters=$(kind get clusters)
  for cluster in "$(dirname "$(realpath "$0")")"/conf/clusters/*.yaml
  do
    name=tap-$(awk -F '/' '{print $NF}' <<< "$cluster" | cut -f1 -d '.')-cluster
    grep -q "$name" <<< "$clusters" || return 1
  done
}

kubernetes_clusters() {
  find "$(dirname "$(realpath "$0")")"/conf/clusters/*.yaml -exec basename {} \; | sed 's/.yaml$//'
}

kubectl_cmd() {
  cmd=(kubectl --context="kind-tap-$1-cluster" "${@:2}")
  >&2 echo "========> ${cmd[*]}"
  "${cmd[@]}"
}

tanzu_cmd() {
  kubectl config use-context "kind-tap-$1-cluster"
  cmd=(/usr/local/bin/tanzu "${@:2}")
  >&2 echo "[$1] ========> ${cmd[*]}"
  "${cmd[@]}"
}

create_namespace_on_all_clusters() {
  for cluster in $(kubernetes_clusters)
  do
    kubectl_cmd "$cluster" get ns tap-install >/dev/null ||
      kubectl_cmd "$cluster" create ns tap-install
  done
}

create_registry_secret() {
  for cluster in $(kubernetes_clusters)
  do
    tanzu_cmd "$cluster" secret registry add tap-registry \
      --username admin \
      --password supersecret \
      --server registry:50000 \
      --export-to-all-namespaces --yes --namespace tap-install
  done
}

add_package_repository() {
  for cluster in $(kubernetes_clusters)
  do
    tanzu_cmd "$cluster" package repository add tanzu-tap-repository \
      --url registry:50000/tap-1.4.0/tap-packages:1.4.0 \
      --namespace tap-install --verbose=9
  done
}

update_kapp_controller_config() {
  updated_ca_certs=$(printf '{"data":{"caCerts":"%s","dangerousSkipTLSVerify": "registry"}}' \
    "$(sed 's/$/\\n/' "$CERT_PATH/cert.pem" | tr -d '\n' | base64 -w 0)")
  for cluster in $(kubernetes_clusters)
  do
    >&2 echo "===> INFO: Adding registry cert to kapp-controller config on cluster $cluster"
    kubectl_cmd "$cluster" -n kapp-controller patch secret kapp-controller-config \
      --type=merge \
      --patch "$updated_ca_certs" &&
      kubectl_cmd "$cluster" delete pod -n kapp-controller -l app=kapp-controller
    done
}

confirm_registry_running() {
  if ! nc -z localhost 50000
  then
    >&2 echo "ERROR: The local Docker registry is probably not running. Run \
./2-provision-registry.sh to start it up!"
    return 1
  fi
}

confirm_registry_running || exit 1


if ! kubernetes_clusters_started
then >&2 echo "ERROR: None or some Kubernetes clusters missing. \
Please run 0-create-kind-cluster before running this script."
  exit 1
fi

create_namespace_on_all_clusters &&
  create_registry_secret &&
  update_kapp_controller_config &&
  add_package_repository
