#!/usr/bin/env bash
usage() {
  cat <<-EOF
Downloads TAP packages into your registry, as recommended by the docs.
Usage: $(basename "$0") [TANZU-NET-USERNAME] [TANZU-NET-PASSWORD]
EOF
  echo "$1"
  exit "${2:-0}"
}
IMGPKG_APP_PATH="${TMPDIR:-/tmp}/tanzu/cluster-essentials/imgpkg"
export TARGET_REPOSITORY=tap
export INSTALL_REGISTRY_USERNAME="${1?$(usage "Please provide your Tanzu Network username." 1)}"
export INSTALL_REGISTRY_PASSWORD="${2?$(usage "Please provide your Tanzu Network password." 1)}"
export TAP_VERSION=1.4.0
local_registry_port() {
  local_port=$(docker inspect registry --format '{{ with (index (index .NetworkSettings.Ports "443/tcp" ) 0) }}{{ .HostPort }}{{ end }}')
  if test -z "$local_port"
  then
    >&2 echo "ERROR: Unable to determine local port for local image registry."
    exit 1
  fi
  echo "$local_port"
}

login_to_local_regsitry() {
  docker login "localhost:$(local_registry_port)" -u admin -p supersecret
}

login_to_tap_registry() {
  docker login registry.tanzu.vmware.com -u "$INSTALL_REGISTRY_USERNAME" \
    -p "$INSTALL_REGISTRY_PASSWORD"
}

slurp_images() {
  "$IMGPKG_APP_PATH" copy \
    -b "registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.4.0" \
      --to-repo "https://localhost:$(local_registry_port)/tap-1.4.0/tap-packages" \
      --registry-insecure
}

login_to_local_regsitry &&
  login_to_tap_registry &&
  slurp_images
