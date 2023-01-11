#!/usr/bin/env bash
TANZU_VERSION=1.4.0
TANZU_CLI_DIRECTORY="$HOME/tanzu"
TANZU_CLI_PIVNET_PACKAGE="tanzu-cli-tap-${TANZU_VERSION}"
TANZU_CLI_TAR_FILE="${TANZU_CLI_DIRECTORY}/tanzu-framework-darwin-amd64.tar"

tanzu_cli_tar_present() {
  test -f "$TANZU_CLI_TAR_FILE"
}

extract_tanzu_cli_tar() {
  test -f "$TANZU_CLI_DIRECTORY/cli-extracted" && return 0

  tar -xvf "$TANZU_CLI_TAR_FILE" -C "$TANZU_CLI_DIRECTORY" &&
    touch "$TANZU_CLI_DIRECTORY/cli-extracted"
}

install_tanzu_cli() {
  trap 'popd &>/dev/null' INT HUP EXIT RETURN
  &>/dev/null pushd "$TANZU_CLI_DIRECTORY" || return 1
  cli_bin=$(find cli -type f -name tanzu-core-darwin_amd64 | head -1)
  if ! test -f "$cli_bin"
  then
    >&2 echo "ERROR: CLI binary not found."
    return 1
  fi
  TANZU_CLI_NO_INIT=true install "$cli_bin" /usr/local/bin/tanzu &&
    chmod +x /usr/local/bin/tanzu
}

install_tanzu_plugins() {
  trap 'popd &>/dev/null' INT HUP EXIT RETURN
  &>/dev/null pushd "$TANZU_CLI_DIRECTORY" || return 1
  TANZU_CLI_NO_INIT=true tanzu plugin install --local cli all
}

if ! tanzu_cli_tar_present
then
  >&2 echo "ERROR: You'll need to install the Tanzu CLI from the Tanzu Network.

Visit https://network.tanzu.vmware.com and download the '$TANZU_CLI_PIVNET_PACKAGE' into \
$TANZU_CLI_DIRECTORY"
  exit 1
fi

extract_tanzu_cli_tar &&
  install_tanzu_cli &&
  install_tanzu_plugins
