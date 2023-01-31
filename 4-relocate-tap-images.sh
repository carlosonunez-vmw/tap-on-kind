#!/usr/bin/env bash
usage() {
  cat <<-EOF
Downloads TAP packages into your registry, as recommended by the docs.
Usage: $(basename "$0") [TANZU-NET-USERNAME] [TANZU-NET-PASSWORD]
EOF
  echo "$1"
  exit "${2:-0}"
}
IMGPKG_APP_PATH="$(dirname "$(realpath "$0")")/.data/tanzu/cluster-essentials/imgpkg"
export TARGET_REPOSITORY=tap
export INSTALL_REGISTRY_USERNAME="${1?$(usage "Please provide your Tanzu Network username." 1)}"
export INSTALL_REGISTRY_PASSWORD="${2?$(usage "Please provide your Tanzu Network password." 1)}"
export TAP_VERSION=1.4.0

login_to_local_regsitry() {
  docker login "localhost:50000" -u admin -p supersecret
}

login_to_tap_registry() {
  docker login registry.tanzu.vmware.com -u "$INSTALL_REGISTRY_USERNAME" \
    -p "$INSTALL_REGISTRY_PASSWORD"
}

slurp_images() {
  "$IMGPKG_APP_PATH" copy \
    -b "registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.4.0" \
      --to-repo "localhost:50000/tap-1.4.0/tap-packages" \
      --registry-insecure \
      --registry-verify-certs=false
}

login_to_local_regsitry &&
  login_to_tap_registry &&
  slurp_images
