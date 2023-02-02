#!/usr/bin/env bash
source "$(dirname "$0")/include/profiles.sh"
CERT_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/registry/certs"
TEMPLATE_PATH="$(dirname "$(realpath "$0")")/conf/profile.tmpl"
RENDERED_TEMPLATE_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/profiles"
CLUSTER_NAMES=$(profiles_to_install)

kubernetes_clusters_started() {
  clusters=$(kind get clusters)
  for cluster in "${CLUSTER_NAMES[@]}"
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

render_profile_template() {
  test -d "$RENDERED_TEMPLATE_PATH" || mkdir -p "$RENDERED_TEMPLATE_PATH"
  for cluster in "${CLUSTER_NAMES[@]}"
  do
    cert=$(awk '{printf "%s\\n    ", $0}' "$CERT_PATH/cert.pem")
    sed "s;%REGISTRY_CERT_HERE%;$cert;" "$TEMPLATE_PATH" |
      sed "s/%PROFILE_NAME%/$cluster/g" > "${RENDERED_TEMPLATE_PATH}/$cluster.yaml"
  done
}

install_tap() {
  for cluster in "${CLUSTER_NAMES[@]}"
  do
    tanzu_cmd "$cluster" package install tap \
      -p tap.tanzu.vmware.com \
      -v 1.4.0 \
      --values-file "${RENDERED_TEMPLATE_PATH}/${cluster}.yaml" \
      -n tap-install
  done
}

create_tap_install_namespace() {
  for cluster in "${CLUSTER_NAMES[@]}"
  do
    kubectl_cmd "$cluster" get ns tap-install ||
      kubectl_cmd "$cluster" create ns tap-install
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

create_tap_install_namespace &&
  render_profile_template &&
  install_tap
